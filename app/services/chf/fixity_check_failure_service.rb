module CHF
  class FixityCheckFailureService
    attr_reader :log_date, :checksum_audit_log, :file_set

    def initialize(file_set, checksum_audit_log:)
      @file_set = file_set
      @checksum_audit_log = checksum_audit_log
    end

    def call
      # send an email to digital-tech
      ActionMailer::Base.mail(from: "digital-tech@sciencehistory.org",
                              to: "digital-tech@sciencehistory.org",
                              subject: subject,
                              content_type: "text/html",
                              body: message).deliver_later

      # Send in-app messages to all admins. Who knows if sendio will
      # block the email anyway.
      admin_role = Role.where(name: 'admin').first
      if admin_role
        admin_role.users.each do |user|
          ::User.audit_user.send_message(user, message, subject)
        end
      end

      # Honeybadger notify
      if defined? Honeybadger
        Honeybadger.notify("Fixity check failure", context: {
          file_set: @file_set.inspect,
          checksum_audit_log: @checksum_audit_log.inspect,
          expected_result: expected_result,
          fedora_uri: checked_uri_fedora_metadata_uri
        })
      end
    end

    def message
      <<-EOF
<p>hostname: #{`hostname`.chomp}
</p>

<p>Fixity check failure at #{log_created_at}<br>
  for: #{checked_uri_fedora_metadata_uri}
</p>

<p>Expected fixity result: #{expected_result}
</p>

<p>work:
  #{works_message}
</p>


<p>file_set: #{file_set_id} #{file_set_title}<br>
  <a href="#{file_set_app_path}">#{file_set_app_path}</a><br>
  #{file_set_fedora_metadata_uri}
</p>

<p>file: #{file_id}<br>
  #{file_fedora_metadata_uri}
</p>

<p>Logged in ChecksumAuditLog: #{ERB::Util.html_escape checksum_audit_log.inspect}</p>
  EOF
    end

    def subject
      "FIXITY CHECK FAILURE: #{Socket.gethostname}: #{file_set_title}"
    end

    protected

    def file_id
      checksum_audit_log.file_id
    end

    def works
      file_set.try(:in_works) || []
    end

    def works_message
      works.to_a.collect do |w|
        "  #{w.try(:title).try(:first)} #{w.id} <a href='#{Rails.application.routes.url_helpers.curation_concerns_generic_work_path(w)}'>#{Rails.application.routes.url_helpers.curation_concerns_generic_work_path(w)}</a>"
      end.join("\n")
    end

    # with actual hostname (prob internal IP) replaced with `FEDORA`
    def file_fedora_metadata_uri
      file_uri = Hydra::PCDM::File.translate_id_to_uri.call(file_id)
      file_uri && prepare_display_uri("#{file_uri}/fcr:metadata")
    end

    # with actual hostname (prob internal IP) replaced with `FEDORA`
    def file_set_fedora_metadata_uri
      if file_set
        prepare_display_uri("#{file_set.uri}/fcr:metadata")
      end
    end

    def checked_uri_fedora_metadata_uri
      prepare_display_uri("#{checked_uri}/fcr:metadata")
    end

    def log_created_at
      checksum_audit_log.try(:created_at).try(:in_time_zone).try(:to_s)
    end

    def file_set_id
      checksum_audit_log.try(:file_set_id)
    end

    def file_set_title
      file_set.try(:title).try(:first)
    end

    def file_set_app_path
      Rails.application.routes.url_helpers.curation_concerns_file_set_path(works.first, file_set) if file_set && works.present?
    end

    def checked_uri
      checksum_audit_log.try(:checked_uri)
    end

    def expected_result
      checksum_audit_log.try(:expected_result)
    end

    # replace real hostname with 'FEDORA', cause real hostname is probably
    # an AWS internal-only IP address, and we don't have access to the actual
    # external hostname/IP at present.  Replace fcr:verisons with escaped
    # version because of bug in fedora. https://jira.duraspace.org/browse/FCREPO-1247
    def prepare_display_uri(uri)
      uri.to_s.sub(%r{//[^/]+(:\d{1,4})/}, '//FEDORA\1/').sub(/fcr:versions/, "fcr%3aversions")
    end
  end
end

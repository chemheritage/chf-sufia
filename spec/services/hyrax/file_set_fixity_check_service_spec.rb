require 'spec_helper'

# Testing our backported Hyrax::FileSetFixityCheckService, but
# also testing that our customized "failure" hook is called, so
# spec probably of use even after our backport is removed.
#
# Sort of a high-level integration-type spec, in that it intentionally
# exersizes a bunch of classes at once, only mocking the actual fedora
# response. Sorry, there's plusses and minuses.
describe Hyrax::FileSetFixityCheckService do
  context "fixity failure" do
    let(:file_set) { FactoryGirl.create(:file_set, title: ["sample.jpg"], content: StringIO.new("adfadf")) }
    let(:file_id) { file_set.original_file.id }
    let(:checked_uri) { file_set.original_file.versions.last.uri }

    let(:service) { Hyrax::FileSetFixityCheckService.new(file_set, async_jobs: false) }
    let(:expected_message_digest) { "urn:sha1:8557baf29574415034f41ce2cc3e65f55faf937e" }
    let(:mock_fedora_service) { double('mock fixity check service') }

    before do
      allow(ActiveFedora::FixityService).to receive(:new).and_return(mock_fedora_service)
      allow(mock_fedora_service).to receive(:check).and_return(false)
      allow(mock_fedora_service).to receive(:expected_message_digest).and_return(expected_message_digest)
    end

    it "creates log and notifies" do
      service.fixity_check

      expect(ChecksumAuditLog.count).to eq 1
      log = ChecksumAuditLog.first
      expect(log.file_set_id).to eq file_set.id
      expect(log.file_id).to eq file_id
      expect(log.checked_uri).to eq checked_uri
      expect(log.expected_result).to eq expected_message_digest
      expect(log.passed?).to be false

      expect(ActionMailer::Base.deliveries.count).to eq(1)
      last_email = ActionMailer::Base.deliveries.last

      expect(last_email.to).to eq(["digital-tech@sciencehistory.org"])
      expect(last_email.from).to eq(["digital-tech@sciencehistory.org"])
      expect(last_email.subject).to match(/\AFIXITY CHECK FAILURE: #{Regexp.escape(Socket.gethostname)}: sample\.jpg\Z/)

      expect(last_email.body.to_s).to include(file_set.id)
      expect(last_email.body.to_s).to include(file_id)
      expect(last_email.body.to_s).to include(URI.parse(checked_uri).path.sub("fcr:versions", "fcr%3aversions"))
      expect(last_email.body.to_s).to include(expected_message_digest)
      expect(last_email.body.to_s).to include(log.created_at.in_time_zone.to_s)
      expect(last_email.body.to_s).to include("ChecksumAuditLog id: #{log.id}")
    end
  end
end

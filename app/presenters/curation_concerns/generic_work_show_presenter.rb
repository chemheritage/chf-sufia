module CurationConcerns
  class GenericWorkShowPresenter < Sufia::WorkShowPresenter
    # There's no such thing as self.terms in the presenter anymore.

    delegate :genre_string, :medium, :physical_container, :creator_of_work,
      :artist, :author, :addressee, :interviewee, :interviewer,
      :manufacturer, :photographer, :place_of_interview,
      :place_of_manufacture, :place_of_creation, :place_of_publication,
      :extent, :division, :series_arrangement, :rights_holder,
      :credit_line, :additional_credit, :file_creator, :admin_note,
      :inscription, :date_of_work, :engraver, :printer,
      :printer_of_plates, :after,
      to: :solr_document

    def additional_title
      @additional_title ||= solr_document.additional_title.try(:sort)
    end

    def has_rights_statement?
      rights.present?
    end

    def rights_icon(identifier = rights.first)
      # schema allows multiple rights, we only use one.
      # we have added our own metadata to the liceneses.yml that the CC
      # class doens't really have accessors for, we'll kinda hack it.
      case CurationConcerns::LicenseService.new.authority.find(identifier).fetch("category", nil)
      when "in_copyright"
        "rightsstatements-InC.Icon-Only.dark.svg"
      when "no_copyright"
        "rightsstatements-NoC.Icon-Only.dark.svg"
      else
        "rightsstatements-Other.Icon-Only.dark.svg"
      end
    end

    def rights_url(identifier = rights.first)
      # we use resolvable urls already
      identifier
    end

    def rights_icon_label(identifier = rights.first)
      # we have added our own metadata to the liceneses.yml that the CC
      # class doens't really have accessors for, we'll kinda hack it.
      CurationConcerns::LicenseService.new.authority.find(identifier).fetch("short_label_html", "").html_safe
    end

    # Override to only display if NOT open access. We assume open access, but
    # want a warning to logged-in staff if viewing something not public.
    def permission_badge
      if needs_permission_badge?
        super
      end
    end
    def needs_permission_badge?
      solr_document.visibility != Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
    end

    # override to cache, cause it's expensive and we need it twice to display
    # our viewer with thumbs, at present.
    # See https://github.com/samvera-labs/hyrax/pull/1160
    def member_presenters(*args)
      # cache based on args, gah. We really don't understand what's going on,
      # but we need to do something with this super-expensive call to make it less so,
      # to support our custom show/viewer.
      @_member_presenters ||= {}
      @_member_presenters[args] ||= super
    end

    # Member presenters, but if our representative image is the FIRST image,
    # don't bother repeating it below.
    def show_thumb_member_presenters
      @show_thumb_member_presenters ||= begin
        if member_presenters.present? && member_presenters.first.id == representative_id
          member_presenters.dup.tap { |a| a.delete_at(0) }
        else
          member_presenters
        end
      end
    end

    def riiif_file_id
      return unless member_presenters.present?
      representative_presenter = member_presenters.select{ |pres| pres.id == representative_id }.pop
      representative_presenter.riiif_file_id
    end
  end
end

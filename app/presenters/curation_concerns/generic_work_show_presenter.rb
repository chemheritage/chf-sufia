module CurationConcerns
  class GenericWorkShowPresenter < Sufia::WorkShowPresenter
    include ActionView::Helpers::TextHelper # for truncate
    include ActionView::Helpers::SanitizeHelper # for strip_tags
    # There's no such thing as self.terms in the presenter anymore.

    delegate :genre_string, :medium, :physical_container, :creator_of_work,
      :artist, :author, :addressee, :interviewee, :interviewer,
      :manufacturer, :photographer, :place_of_interview,
      :place_of_manufacture, :place_of_creation, :place_of_publication,
      :extent, :division, :exhibition, :series_arrangement, :rights_holder,
      :credit_line, :additional_credit, :file_creator, :admin_note,
      :inscription, :date_of_work, :engraver, :printer,
      :printer_of_plates, :after, :thumbnail_path,
      to: :solr_document

    # to make it more like a Blacklight presenter, so we can use
    # logic in common, it needs a viewcontet. We'll override
    # method in controller to make sure it gets set. Hacky, but this
    # is what we're doing.
    attr_accessor :view_context

    # Don't entirely understand what this is doing, but it returns
    # some 'collection presenters', zero to many, each item is a parent work presenter.
    def parent_work_presenters
      # no idea why we have to `flatten`, the stack `grouped_presenters` method is
      # confusing and barely documented.
      @parent_work_presenters ||= grouped_presenters(filtered_by: "generic_work").values.flatten
    end

    # similar to parent_work_presenters, but for collections. Yes, this is all confusing.
    def in_collection_presenters
      @in_collection_presenters ||= grouped_presenters(filtered_by: "collection").values.flatten
    end

    def catalog_bib_numbers
      @catalog_big_numbers ||= solr_document.identifier.
        find_all { |id| id.start_with?("bib-") }.
        collect { |id| id.gsub(/\Abib-/, '').downcase }.
        # sometimes have an extra digit, should never have more than b+7
        # https://github.com/chemheritage/chf-sufia/issues/862
        collect { |id| id.slice(0, 8) }
    end

    def urls_to_catalog
      @urls_to_catalog ||= catalog_bib_numbers.collect do |bib_num|
        "http://othmerlib.sciencehistory.org/record=#{CGI.escape bib_num}"
      end
    end

    def additional_title
      @additional_title ||= solr_document.additional_title.try(:sort)
    end

    def has_rights_statement?
      rights.present?
    end

    def rights_icon(identifier = rights.first)
      # schema allows multiple rights, we only use one.
      # we have added our own metadata to the licenses.yml used by
      # CC/QA, but the CC/QA code makes it difficult to access
      # efficiently, so we use our own CHF::RightsTerms
      case CHF::RightsTerms.category_for(identifier)
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
      (CHF::RightsTerms.short_label_html_for(identifier) || "").html_safe
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

    # used for social media shares
    def short_plain_description
      # we want it not escaped but also not marked html_safe, cause we're gonna use it in a URL
      # but also want it safe for using in a view. Rails truncate helper makes this hard!
      @short_plain_description ||= "#{truncate(
        strip_tags(description.first),
        escape: false,
        length: 400,
        separator: /\s/
      )}"
    end

    # If it's a child work, return the child work, don't go further to fileset. Gives
    # us better for what we need in current customized app on show page.
    def direct_representative_presenter
      return nil if representative_id.blank?
      @direct_representative_presenter ||= member_presenters([representative_id]).first
    end

    # Like member_presenters without args, but filters to only those current
    # user has permissions to see. Used on our show page and viewer.
    #
    # Memoized -- building member_presenters can be expensive and we
    # call multiple times in our views, important to cache.
    def viewable_member_presenters
      @viewable_member_presenters ||= member_presenter_factory.permitted_member_presenters(action: :read)
    end

    # viewable_member_presenters, but if our representative image is the FIRST image,
    # don't repeat it below.
    def show_thumb_member_presenters
      @show_thumb_member_presenters ||= begin
        if viewable_member_presenters.present? && viewable_member_presenters.first.id == representative_id
          viewable_member_presenters.dup.tap { |a| a.delete_at(0) }
        else
          viewable_member_presenters
        end
      end
    end

    def representative_file_id
      Array.wrap(solr_document[ActiveFedora.index_field_mapper.solr_name('representative_original_file_id')]).first
    end

    def representative_file_set_id
      Array.wrap(solr_document[ActiveFedora.index_field_mapper.solr_name('representative_file_set_id')]).first
    end

    def representative_checksum
      Array.wrap(solr_document[ActiveFedora.index_field_mapper.solr_name('representative_checksum')]).first
    end

    def representative_height
      Array.wrap(solr_document[ActiveFedora.index_field_mapper.solr_name('representative_height', type: :integer)]).first
    end

    def representative_width
      Array.wrap(solr_document[ActiveFedora.index_field_mapper.solr_name('representative_width', type: :integer)]).first
    end

    # handy for use with field_value below
    def has_values_for?(field_name)
      solr_document[field_name].present?
    end

    # Copied from Blacklight presenter, so we can use the same logic we use in 'index'
    # presenters here.
    #
    # https://github.com/projectblacklight/blacklight/blob/v6.11.2/app/presenters/blacklight/index_presenter.rb#L54-L57
    #
    # Render the index field label for a document
    #
    # Allow an extention point where information in the document
    # may drive the value of the field
    # @param [String] field
    # @param [Hash] options
    # @option options [String] :value
    def field_value field, options = {}
      field_config = field_config(field)
      field_values(field_config, options)
    end

    private

      # Copied from Blacklight presenter, so we can use the same logic we use in 'index'
      # presenters here.
      #
      # https://github.com/projectblacklight/blacklight/blob/v6.11.2/app/presenters/blacklight/index_presenter.rb#L96
      #
      #
      # Get the value for a document's field, and prepare to render it.
      # - highlight_field
      # - accessor
      # - solr field
      #
      # Rendering:
      #   - helper_method
      #   - link_to_search
      # @param [Blacklight::Configuration::Field] field_config solr field configuration
      # @param [Hash] options additional options to pass to the rendering helpers
      def field_values(field_config, options={})
        Blacklight::FieldPresenter.new(view_context, solr_document, field_config, options).render
      end

      # Copied from Blacklight presenter, so we can use the same logic we use in 'index'
      # presenters here. BUT take configuration from CatalogController
      #
      # https://github.com/projectblacklight/blacklight/blob/v6.11.2/app/presenters/blacklight/index_presenter.rb#L100
      def field_config(field)
        ::CatalogController.blacklight_config.index_fields.fetch(field) { Blacklight::Configuration::NullField.new(field) }
      end


  end
end

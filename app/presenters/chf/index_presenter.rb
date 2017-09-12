module Chf
  # Unlike the show presenters based on sufia code, the index presenter
  # is based on Blacklight code. It is used on the search results screen,
  # and is used for ALL models, the Blacklight architecture doesn't choose
  # different presenters for different models.
  #
  # We supply some custom methods to make it appear more like a sufia
  # presenter, to allow some code sharing. Yes, this is a dangerous game,
  # hard to know if we have API-compatibility with the other one, but this
  # was the lesser evil.
  class IndexPresenter < Blacklight::IndexPresenter
    delegate :description, :thumbnail_path, :id, to: :solr_document

    # Make it look more like a sufia presenter
    def current_ability
      view_context.try(:current_ability)
    end

    # sufia presenters call it this, so we provice this to make code-sharing
    # easier.
    def solr_document
      document
    end

    # More like sufia presenter
    def request
      view_context.request
    end

    # handy
    def has_values_for?(field_name)
      solr_document[field_name].present?
    end

    # Currently indexed as all members, regardless of public/private access controls
    # returned as single integer. The member_ids_ssim list is indexed by some
    # upstream part of the stack.
    def num_members
      solr_document["member_ids_ssim"].try(:length) || 0
    end

    # used on both work and collection results partials, so useful to have
    # it in presenter for DRY. Fortunately we have a view_context so we can use
    # helpers. Also how many times we called `doc_presenter` in this logic
    # suggests this may be the right place for it.
    def render_num_members
      if num_members
        label = view_context.number_with_delimiter(num_members) + ' item'.pluralize(num_members)

        view_context.content_tag("div", class: "chf-results-list-item-num-members") do
          if num_members > 0 && representative_file_id.present?
              view_context.link_to(label, view_context.viewer_path(id, representative_id))
          else
            label
          end
        end
      end
    end

    # deserialize our json to get a list of ids and titles, usually
    # zero or one but who knows.
    def parent_work_info
      @parent_work_info ||= begin
        json = solr_document["parent_work_info_ss"]
        json.present? ? JSON.parse(json) : []
      end
    end

    # "representative_" methods are copied from GenericWorkShowPresenter, so
    # we can use this presenter the same way for displaying representative images.
    # Possible improvement: DRY this code between here and there.
    def representative_id
      solr_document.representative_id
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

    def needs_permission_badge?
      solr_document.visibility != Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
    end

    # Copied from curationconcerns presenter.
    # https://github.com/samvera/curation_concerns/blob/v1.7.7/app/presenters/curation_concerns/presents_attributes.rb#L23-L29
    def permission_badge
      CurationConcerns::PermissionBadge.new(solr_document).render
    end
  end
end

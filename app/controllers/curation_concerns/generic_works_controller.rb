# Generated via
#  `rails generate curation_concerns:work GenericWork`

module CurationConcerns
  class GenericWorksController < ApplicationController
    include CurationConcerns::CurationConcernController
    # Adds Sufia behaviors to the controller.
    include Sufia::WorksControllerBehavior

    self.curation_concern_type = GenericWork
    self.show_presenter = CurationConcerns::GenericWorkShowPresenter

    # our custom local layout intended for public show page, but does
    # not seem to mess up admin pages also in this controller.
    layout "chf"

    # returns JSON for the viewer, an array of hashes, one for each image
    # included in this work to be viewed.
    # Note we needed to make this action auth right with a custom line in
    # in our ability.rb class.
    def viewer_images_info
      render json: helpers.viewer_images_info(presenter)
    end

    def update
      items_to_convert = params['convert'] ||= {}
      items_to_convert.each_pair do |member_id, action|
        if action == "promote_to_child_work"
          puts "Converting to child work: "
          puts params['id']
          to_child_work(member_id, params['id'])
        end
        if action == "demote_to_fileset"
          puts "Converting to fileset: "
          puts params['id']
          to_fileset(member_id,  params['id'])
        end
      end
      # super in this case is:
      # /curation_concerns-1.7.8/app/controllers/concerns/curation_concerns/curation_concern_controller.rb
      super
    end


  include CurationConcerns::Lockable

  #Promote a FileSet to a child GenericWork.
  def to_child_work (filesetid, parentworkid)
    parent_work = GenericWork.find(parentworkid)
    file_set = parent_work.members.to_a.find { |x| x.id == filesetid }
    return if file_set == nil
    new_child_work = GenericWork.new(title: file_set.title)
    acquire_lock_for(parent_work.id) do
        new_child_work.apply_depositor_metadata(current_user.user_key)
        new_child_work.admin_set_id = "admin_set/default"
        new_child_work.state = parent_work.state # active
        new_child_work.part_of = parent_work.part_of
        new_child_work.identifier = parent_work.identifier
        new_child_work.visibility = parent_work.visibility
        new_child_work.creator = [current_user.user_key]
        new_child_work.save!

        parent_work.ordered_members.delete(file_set)
        parent_work.members.delete(file_set)

        # ActiveFedora::RecordInvalid (Validation failed
        # Representative must be included in members and ordered_members,
        # Thumbnail must be included in members and ordered_members)
        if parent_work.thumbnail_id == file_set.id
          parent_work.thumbnail = nil
        end

        if parent_work.representative_id == file_set.id
          parent_work.representative = nil
        end
        parent_work.save!
        new_child_work.ordered_members << file_set
        new_child_work.members.push(file_set)
        new_child_work.representative_id = file_set.id
        new_child_work.thumbnail_id = file_set.id
        new_child_work.save!
        parent_work.ordered_members << new_child_work
        parent_work.members.push(new_child_work)
        parent_work.save!
    end
  end

  def to_fileset (childworkid, parentworkid)
    parent_work = GenericWork.find(parentworkid )
    child_work = parent_work.members.to_a.find { |x| x.id == childworkid }
    file_set = child_work.members.first

    acquire_lock_for(parent_work.id) do
        parent_work.ordered_members.delete(child_work)
        parent_work.members.delete(child_work)
        parent_work.save!

        parent_work.ordered_members << file_set
        parent_work.representative_id = file_set.id
        parent_work.thumbnail_id = file_set.id
        parent_work.save!
        child_work.delete
    end

    #flash[:notice] = "\"#{file_set.title.first}\" has been demoted to a file attached to \"#{parent_work.title.first}\". All metadata associated with the child work has been deleted."
    #redirect_to "/concern/parent/#{parent_work.id}/file_sets/#{file_set.id}"

  end


    protected

    # override from curation_concerns to add additional response formats to #show
    def additional_response_formats(wants)
      wants.ris do
        # Terrible hack to get download name from our helper
        download_name = helpers._download_name_base(presenter) + ".ris"
        headers["Content-Disposition"] = ApplicationHelper.encoding_safe_content_disposition(download_name)

        render body: CHF::RisSerializer.new(presenter).to_ris
      end

      wants.csl do
        # Terrible hack to get download name from our helper
        download_name = helpers._download_name_base(presenter) + ".json"
        headers["Content-Disposition"] = ApplicationHelper.encoding_safe_content_disposition(download_name)

        render body: CHF::CitableAttributes.new(presenter).to_csl_json
      end

      # Provide our OAI-PMH representation as "xml", useful for debugging,
      # maybe useful for clients.
      wants.xml do
        render xml: CHF::OaiDcSerialization.new(curation_concern_from_search_results).to_oai_dc(xml_decleration: true)
      end
    end

    # Pretty hacky way to override the t() I18n method when called from template:
    # https://github.com/projecthydra/sufia/blob/8bb451451a492e443687f8c5aff4882cac56a131/app/views/curation_concerns/base/_relationships_parent_row.html.erb
    # ...so  we can catch what would have been "In Generic work" and replace with
    # "Part of", while still calling super for everything else, to try and
    # avoid breaking anything else.
    #
    # The way this is set up upstream, I honestly couldn't figure out
    # a better way to intervene without higher chance of forwards-compat
    # problems on upgrades. It could not be overridden just in i18n to do
    # what we want.
    module HelperOverride
      def t(key, interpolations = {})
        if key == ".label" && interpolations[:type] == "Generic work"
          "Part of:"
        else
          super
        end
      end
    end
    helper HelperOverride

    # Adds the 'My Works' breadcrumb; we only want this for logged-in users
    # overrides https://github.com/samvera/sufia/blob/v7.3.1/app/controllers/concerns/sufia/works_controller_behavior.rb#L93
    def add_breadcrumb_for_controller
      super if current_ability.current_user.logged_in?
     end

    # Show breadcrumbs to all users, even if they're not logged in...
    def show_breadcrumbs?
      true # this overrides the default case in application_controller.rb .
    end

    # ... but, for not-logged-in users, only show the "Back to Search Results" breacrumb.
    def build_breadcrumbs
      super
      # This method is in application_controller.rb :
      filter_breadcrumbs(@breadcrumbs)
    end

    # overriding presenter to pass in view_context
    def presenter(*args)
      super.tap do |pres|
        pres.view_context = view_context if pres.respond_to?(:view_context=)
      end
    end

  end
end

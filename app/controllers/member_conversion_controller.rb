class MemberConversionController < ApplicationController
  include CurationConcerns::Lockable

  #Promote a FileSet to a child GenericWork.
  def to_child_work
    parent_work = GenericWork.find(params['parentid'])
    file_set = FileSet.find(params['filesetid'])
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
        # parent_work.representative_id = nil
        # parent_work.thumbnail_id = nil
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
    flash[:notice] = "\"#{new_child_work.title.first}\" has been promoted to a child work of \"#{parent_work.title.first}\". Click \"Edit\" to add metadata."
    redirect_to "/works/#{new_child_work.id}"

  end

  def to_fileset
    child_work = GenericWork.find(params['childworkid'] )
    parent_work = GenericWork.find(params['parentworkid'] )
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

    flash[:notice] = "\"#{file_set.title.first}\" has been demoted to a file attached to \"#{parent_work.title.first}\". All metadata associated with the child work has been deleted."
    redirect_to "/concern/parent/#{parent_work.id}/file_sets/#{file_set.id}"
  end
end
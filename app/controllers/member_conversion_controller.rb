class MemberConversionController < ApplicationController
  include CurationConcerns::Lockable

  #Promote a FileSet to a child GenericWork.
  def to_child_work
    parent_work = GenericWork.find(params['parentid'])
    file_set = FileSet.find(params['filesetid'])

    if !validate_for_switch_to_child_work(parent_work, file_set)
      flash[:notice] = "\"#{file_set.title.first}\" can't be promoted to a child work."
      redirect_to "/concern/parent/#{parent_work.id}/file_sets/#{file_set.id}"
    end

    place_in_order = parent_work.ordered_members.to_a.find_index(file_set)

    transfer_thumbnail = (parent_work.thumbnail == file_set)
    transfer_representative = (parent_work.representative == file_set)

    new_child_work = GenericWork.new(title: file_set.title)
    acquire_lock_for(parent_work.id) do
        new_child_work.apply_depositor_metadata(current_user.user_key)
        new_child_work.creator = [current_user.user_key]
        copy_metadata_from_parent(parent_work, new_child_work)
        new_child_work.save!
        parent_work.representative_id = nil if transfer_representative
        parent_work.thumbnail_id = nil if transfer_thumbnail
        remove_member_from_parent(parent_work, file_set)
        parent_work.save!
        add_member_to_parent(new_child_work, file_set, 0)
        set_thumbnail_and_rep(new_child_work, file_set, true, true)
        set_thumbnail_and_rep(parent_work, new_child_work, transfer_thumbnail, transfer_representative)
        new_child_work.save!
        add_member_to_parent(parent_work, new_child_work, place_in_order)
        parent_work.save!

    end
    flash[:notice] = "\"#{new_child_work.title.first}\" has been promoted to a child work of \"#{parent_work.title.first}\". Click \"Edit\" to add metadata."
    redirect_to "/works/#{new_child_work.id}"

  end

  def to_fileset

    parent_work = GenericWork.find(params['parentworkid'] )
    child_work = GenericWork.find(params['childworkid'] )
    if !validate_for_switch_to_fileset(parent_work, child_work)
      flash[:notice] = "Sorry. \"#{child_work.title.first}\" can't be demoted to a file."
      redirect_to "/works/#{child_work.id}"
    end

    place_in_order = parent_work.ordered_members.to_a.find_index(child_work)
    transfer_thumbnail = (parent_work.thumbnail == child_work)
    transfer_representative = (parent_work.representative == child_work)
    file_set = child_work.members.first

    acquire_lock_for(parent_work.id) do
        parent_work.representative_id = nil if transfer_representative
        parent_work.thumbnail_id = nil if transfer_thumbnail
        remove_member_from_parent(parent_work, child_work)
        parent_work.save!
        add_member_to_parent(parent_work, file_set, place_in_order)
        set_thumbnail_and_rep(parent_work, file_set, transfer_thumbnail, transfer_representative)
        parent_work.save!
        child_work.delete
    end

    flash[:notice] = "\"#{file_set.title.first}\" has been demoted to a file attached to \"#{parent_work.title.first}\". All metadata associated with the child work has been deleted."
    redirect_to "/concern/parent/#{parent_work.id}/file_sets/#{file_set.id}"
  end

  private

  def validate_for_switch_to_child_work(parent, member)
    return false unless is_work?(parent)
    return false unless is_fileset?(member)
    return false unless check_connection(parent, member)
    return false if  member.members.to_a.count != 0
    return false if  member.ordered_members.to_a.count != 0
    return true
  end

  def validate_for_switch_to_fileset(parent, member)
    return false unless is_work?(parent)
    return false unless is_work?(member)
    return false unless check_connection(parent, member)
    return false if  member.members.to_a.count != 1
    return false if  member.ordered_members.to_a.count != 1
    return false unless is_fileset? member.members.first
    return true
  end


  def add_member_to_parent(parent, member, place_in_order)
    parent.ordered_members = parent.ordered_members.to_a.insert(place_in_order, member)
    parent.members.push(member)
  end

  def remove_member_from_parent(parent, member)
    parent.ordered_members.delete(member)
    parent.members.delete(member)
  end

  def check_connection(parent, member)
    return false if parent == nil
    return false if member == nil
    return false unless parent.ordered_members.to_a.include? member
    return false unless parent.members.to_a.include? member
    true
  end

  def get_from_parent (parent, member_id)
    parent.members.to_a.find { |x| x.id == member_id }
  end

  def is_fileset?(item)
    item.class.name == "FileSet"
  end

  def is_work?(item)
    item.class.name == "GenericWork"
  end

  def copy_metadata_from_parent(parent, member)
    member.admin_set_id = "admin_set/default"
    member.state = parent.state # active
    member.part_of = parent.part_of
    member.identifier = parent.identifier
    member.visibility = parent.visibility
  end

  def set_thumbnail_and_rep(parent, member, thumbnail, representative)
    if representative
      parent.representative_id = member.id
      parent.representative = member
    end
    if thumbnail
      parent.thumbnail_id = member.id
      parent.thumbnail = member
    end
  end

end





class ConvertFileSetToChildWork < ActiveJob::Base
  include CurationConcerns::Lockable

  attr_reader :parent_work, :file_set, :user

  def perform(parent_work, file_set, user)

    @parent_work, @file_set, @user, = parent_work, file_set, user

    new_child_work = GenericWork.new(title: @file_set.title)
    new_child_work.apply_depositor_metadata(@user.user_key)
    new_child_work.admin_set_id = "admin_set/default"
    new_child_work.state = @parent_work.state # active
    new_child_work.part_of = @parent_work.part_of
    new_child_work.save!

    # OK  -- now disconnect the parent work from the fileset.

    @parent_work.ordered_members.delete(@file_set)
    @parent_work.members.delete(@file_set)
    @parent_work.representative_id = nil
    @parent_work.thumbnail_id = nil
    @parent_work.save!

    # Now attach the fileset to the child work.

    new_child_work.ordered_members << @file_set
    new_child_work.members.push(@file_set)
    new_child_work.representative_id = @file_set.id
    new_child_work.thumbnail_id = @file_set.id
    new_child_work.save!

    ## Finally, add the new child work to the parent work.

    @parent_work.ordered_members << new_child_work
    @parent_work.members.push(new_child_work)
    @parent_work.save!

  end

end
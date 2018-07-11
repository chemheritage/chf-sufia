class ConvertFileSetToChildWorkJob < ActiveJob::Base
  include CurationConcerns::Lockable

  attr_reader :parent_work, :file_set, :user

  rescue_from(StandardError) do |exception|
    Rails.logger.error """[#{self.class.name}] Could not finish converting to child work:
    #{exception.to_s}"""
  end

  # Start with GenericWork -> FileSet
  # End up with GenericWork -> GenericWork -> FileSet.

  # Note: you can try invoking this from the console as follows:


  # parent_work_id = 'rn3011364'
  # user = User.all[0]
  # parent_work = GenericWork.find(parent_work_id)
  # file_set = parent_work.members.first
  # ConvertFileSetToChildWorkJob.perform_later(parent_work, file_set, user)

  def perform(parent_work, file_set, user)

    @parent_work, @file_set, @user, = parent_work, file_set, user

    Rails.logger.info "Validation..."

    #Verify the hierarchy: the file_set has to be a member of the parent_work.

    if !@parent_work.ordered_members.to_a.include?(@file_set)
      raise StandardError, "The parent item doesn't actually contain the file set"
      return
    end


    if !@parent_work.members.to_a.include?(@file_set)
      raise StandardError, "The parent item doesn't actually contain the file set"
      return
    end

    acquire_lock_for(@parent_work.id) do


      Rails.logger.info "Creating child work"

      new_child_work = GenericWork.new(title: @file_set.title)
      new_child_work.apply_depositor_metadata(@user.user_key)
      new_child_work.admin_set_id = "admin_set/default"
      new_child_work.state = @parent_work.state # active
      new_child_work.part_of = @parent_work.part_of
      new_child_work.identifier = @parent_work.identifier
      new_child_work.visibility = @parent_work.visibility
      new_child_work.creator = [user.user_key]
      new_child_work.save!

      # OK  -- now disconnect the parent work from the fileset.


      Rails.logger.info "Disconnecting the parent work from the fileset"

      @parent_work.ordered_members.delete(@file_set)
      @parent_work.members.delete(@file_set)
      @parent_work.representative_id = nil
      @parent_work.thumbnail_id = nil
      @parent_work.save!

      # Now attach the fileset to the child work.
      Rails.logger.info "Attaching the fileset to the child work."

      new_child_work.ordered_members << @file_set
      new_child_work.members.push(@file_set)
      new_child_work.representative_id = @file_set.id
      new_child_work.thumbnail_id = @file_set.id
      new_child_work.save!

      ## Finally, add the new child work to the parent work.

      sleep 3
      Rails.logger.info "Adding the new child work to the parent work."

      sleep 3
      Rails.logger.info "Adding to ordered members...."


      @parent_work.ordered_members << new_child_work


      sleep 3
      Rails.logger.info "Adding to members...."
      @parent_work.members.push(new_child_work)

      sleep 3
      Rails.logger.info "Final save...."
      @parent_work.save!

      sleep 3
      10.times { Rails.logger.info "SUCCESS" }
    end
  end
end
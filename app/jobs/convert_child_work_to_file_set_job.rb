class ConvertChildWorkToFileSetJob < ActiveJob::Base
  include CurationConcerns::Lockable

  attr_reader :parent_work, :child_work, :user


  rescue_from(StandardError) do |exception|
      Rails.logger.error """[#{self.class.name}] Hey, something was wrong with your job:
      #{exception.to_s}"""
  end

  # Start with GenericWork -> GenericWork -> FileSet.
  # End with GenericWork -> FileSet

  # Note: you can try invoking this from the console as follows:

  # parent_work_id = 'rn3011364'
  # user = User.all[0]
  # parent_work = GenericWork.find(parent_work_id)
  # child_work = parent_work.members.to_a.first

  # ConvertChildWorkToFileSetJob.perform_later(parent_work, child_work, user)

  def perform(parent_work, child_work, user)

    @parent_work, @child_work, @user, = parent_work, child_work, user

    Rails.logger.info "Validation..."
    #Verify the hierarchy

    if @child_work.class != GenericWork
      raise StandardError, "The child work is not a work."
      return
    end

    # Verify that child_work only has one fileset associated with it.
    if @child_work.members.to_a.count != 1
      raise StandardError, "This child work doesn't have exactly one fileset."
      return
    end

    # Get a link to the fileset
    file_set = @child_work.members.first

    if file_set.class != FileSet
      raise StandardError, "The parent item doesn't actually contain a file set"
      return
    end

    if !@parent_work.ordered_members.to_a.include?(@child_work)
      raise StandardError, "The parent item doesn't actually contain the child work"
      return
    end

    if !@parent_work.members.to_a.include?(@child_work)
      raise StandardError, "The parent item doesn't actually contain the child work"
      return
    end

    Rails.logger.info "Completed validation"

    acquire_lock_for(@parent_work.id) do

      Rails.logger.info "Removing the child work from the parent work"

      # Remove the child work from the parent work.
      @parent_work.ordered_members.delete(@child_work)
      @parent_work.members.delete(@child_work)
      @parent_work.save!


      # Let's try removing all this crap and moving the child delete until the end.


      # Rails.logger.info "Detaching the fileset from the child work"
      # # Now detach the fileset from the child work.
      # # do we even need this? Unclear.
      # @child_work.representative_id = nil
      # @child_work.thumbnail_id = nil
      # @child_work.ordered_members.delete(file_set)
      # @child_work.members.delete(file_set)
      # @child_work.save!
      # Anyway, now get rid of the child work.
      #####



      Rails.logger.info "Connecting the parent work to the fileset."

      sleep 3

      Rails.logger.info "Adding to ordered members..."
      @parent_work.ordered_members << @file_set

      sleep 3
      Rails.logger.info "Setting representative_id"
      @parent_work.representative_id = @file_set.id

      sleep 3
      Rails.logger.info "Setting thumbnail"
      @parent_work.thumbnail_id = @file_set.id

      sleep 3
      Rails.logger.info "Final save..."
      @parent_work.save!

      sleep 3



      Rails.logger.info "Final step : Getting rid of the child work"
      @child_work.delete
      sleep 3

      10.times { Rails.logger.info "SUCCESS" }
    end
  end
end
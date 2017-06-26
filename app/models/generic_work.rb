# Generated via
#  `rails generate curation_concerns:work GenericWork`
class GenericWork < ActiveFedora::Base
  include ::CurationConcerns::WorkBehavior
  include Sufia::WorkBehavior
  include GenericMetadata

  self.human_readable_type = 'Work'
  self.indexer = CHF::GenericWorkIndexer

  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: 'Your work must have a title.' }

  validate :legal_representative_id, :legal_thumbnail_id

  protected

  def legal_representative_id
    return if representative_id.nil?
    # This is known to cause problems with curation_concerns@608b02916cd7,
    # doesn't make sense to have a representative that's not in members.
    # But happened at least once anyway. Try to prevent it.
    unless ordered_member_ids.include?(representative_id) && member_ids.include?(representative_id)
      errors.add(:representative_id, "must be included in members and ordered_members")
    end
  end

  def legal_thumbnail_id
    return if thumbnail_id.nil?
    # While this is NOT known to cause problems with curation_concerns@608b02916cd7,
    # it does seem to violate the intentional semantics, so we'll prevent it.
    unless ordered_member_ids.include?(thumbnail_id) && member_ids.include?(thumbnail_id)
      errors.add(:thumbnail_id, "must be included in members and ordered_members")
    end
  end
end

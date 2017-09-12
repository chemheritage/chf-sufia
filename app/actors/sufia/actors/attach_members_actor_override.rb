# We are overriding the Actor in the stack that changes child works in a parent,
# so we can trigger a reindex of any child works who have had their parent changed,
# because we need works to index their parents for search results display.
#
# Warning, if a parent gets DELETED, the children may not be automatically reindexed. We don't
# count on that happening, good enough for now.
#
# TODO: NEEDS an integration test!

AttachMembersActorOverride ||= Module.new do
  def update(*_args)
    previous_member_ids = curation_concern.member_ids
    super.tap do
      # get any child works that have been ADDED or REMOVED
      updated_member_ids = curation_concern.member_ids
      changed = previous_member_ids - updated_member_ids | updated_member_ids - previous_member_ids
      # anything that was added or removed, kick off a bg job to reindex it.
      # it's okay if it doesn't happen right right away, I think.
      changed.each do |id|
        ReindexModelJob.perform_later(id)
      end
    end
  end
end

Sufia::Actors::AttachMembersActor.class_eval do
  prepend AttachMembersActorOverride unless self.include?(AttachMembersActorOverride)
end

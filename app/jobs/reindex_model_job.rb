# Job to reindex a single ActiveFedora model, using #update_index.
# Not really used by stack which does these things inline instead of as jobs,
# but we have some cases where it's useful to kick off a reindex of a single
# item as a job.
class ReindexModelJob < ActiveJob::Base
  def perform(id)
    ActiveFedora::Base.find(id).update_index
  end
end

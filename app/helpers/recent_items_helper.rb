# A random selection of recently modified works to display as thumbnails
# on the front page of the site.
# The same selection is shown to all users at the same time.
# The selection is reshuffled few minutes,
# and is cached for speed.
module RecentItemsHelper
  class RecentItems
    @@last_refresh = nil
    @@bag = nil

    def initialize()
      @how_many_works_to_show = 6
      #@how_often_to_change = 60 * 10 # ten minutes
      @how_often_to_change = 5
      @how_many_works_in_bag = 15
    end

    def recent_items()
      @@bag = nil if time_for_a_new_bag?
      srand @@last_refresh
      fetch_bag().sort_by{rand}[0... @how_many_works_to_show]
    end

    private

    def time_for_a_new_bag?()
      return false if ( @@last_refresh != nil && still_fresh? )
      @@last_refresh = Time.now.to_i
      return true
    end

    def still_fresh?()
      ( Time.now.to_i - @@last_refresh ) < @how_often_to_change
    end

    def fetch_bag()
      return @@bag if @@bag != nil
      conds =  {
        'read_access_group_ssim'=>'public'
      }
      opts = {
        :rows=> @how_many_works_in_bag,
        :sort=> ["system_modified_dtsi desc"]
      }
      @@bag = GenericWork.search_with_conditions(conds, opts)
      @@bag
    end
  end #class
end #module
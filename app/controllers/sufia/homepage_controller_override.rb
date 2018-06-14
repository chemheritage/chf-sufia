Sufia::HomepageController.class_eval do
  # we don't actually want our local layout, cause it adds the search bar at the top
  # which we don't want. This is messy, yeah, not sure what this is doing honestly.
  layout 'sufia'


  # The default `Sufia::HomepageSearchBuilder` limits to just works. We actually
  # want everything that shows up in a normal search, but to limit to only public things,
  # to support our live count of items and have it match search results for public users.
  #
  # We override to a custom search builder to do that.
  def search_builder_class
    SearchBuilder::HomePage
  end

  protected

  def public_works_count
    @public_works_count ||= search_results({}).first.total
  end
  helper_method :public_works_count

  def recent_items
    #First, put a bunch of eligible works into a bag:
    conditions =  {'read_access_group_ssim'=>'public'}
    how_many_works_in_bag = 15
    sort_by = ["system_modified_dtsi desc"]
    opts = {:rows=>how_many_works_in_bag, :sort=>sort_by}
    works_to_pick_from = GenericWork.search_with_conditions( conditions, opts)
    # Now, pick a few of these out of the bag at random to show.
    change_selection_randomly_on_each_page_load = false
    if !change_selection_randomly_on_each_page_load
      # Shuffle every few minutes instead:
      how_often_to_change = 60 * 10 # ten minutes in seconds
      srand Time.now.to_i/how_often_to_change
    end
    how_many_works_to_show = 5
    works_to_pick_from.sort_by{rand}[0..how_many_works_to_show-1]
  end
  helper_method :recent_items

end

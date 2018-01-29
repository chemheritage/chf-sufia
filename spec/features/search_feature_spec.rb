require 'rails_helper'

# Some top-level 'smoke tests' to make sure the app is working.

# Feature tests are really slow always, and even slower cause it's so slow
# for us to create records in samvera. So we pack a bunch of stuff
# into each scenario, even though that's often said to be not great test design.

# This includes not just searching, but results on record show page

RSpec.feature "Search smoke-tests", js: true do
  before do
    # fits may not be installed on travis, and is slow. Try to keep it from happening.
    # Alternately, if we really want to install fits on travis:
    # https://github.com/ucsblibrary/alexandria/blob/master/.travis.yml#L24-L27
    allow_any_instance_of(CharacterizeJob).to receive(:perform).and_return(nil)
  end
  let!(:record1) { FactoryGirl.create(:full_public_work, title: ["Record One"]) }
  let!(:record2) { FactoryGirl.create(:full_public_work, title: ["Record Two"]) }

  # super cheesy way that works to have a shared example
  shared_examples "searching" do
    scenario "searching" do
      visit(root_path)
      fill_in 'q', with: 'two'
      click_button 'Search'

      # Results page
      expect(page).to have_current_path(search_catalog_path, only_path: true)
      expect(page).to have_css(".page_links", text: "1 entry found")
      expect(page).to have_css("li.document", count: 1)
      click_link "Record Two"

      # Record Two show page, check for some features on page
      expect(page).to have_current_path(curation_concerns_generic_work_path(record2.id), only_path: true)
      expect(page).to have_text(record2.genre_string.join(","))
      expect(page).to have_text(record2.title.first)
      expect(page).to have_link(text: record2.author.first, href: search_catalog_path(f: {maker_facet_sim: [record2.author.first]}))

      # image is there. too hard to check actual src url at present.
      expect(page).to have_css("img.show-page-image-image")

      # download menu opens
      click_button "Download"
      expect(page).to have_css(".dropdown-menu.download-menu")
      expect(page).to have_link("Original file")
    end
  end

  context("as a not-logged in user") do
    include_examples "searching"
  end

  context("as a logged-in user") do
    before do
      user = FactoryGirl.create(:user)
      login_as(user, :scope => :user)
    end

    include_examples "searching"
  end
end

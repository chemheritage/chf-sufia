require 'rails_helper'

# Feature tests are really slow always, and even slower cause it's so slow
# for us to create records in samvera. So we pack a bunch of stuff
# into each scenario, even though that's often said to be not great test design.

RSpec.feature "Collections", js: true do
  let(:title) { "test object" }
  let(:subject) { "some subject" }
  let!(:work) { FactoryGirl.create(:work, :with_complete_metadata, title: [title], subject: [subject]) }
  let!(:collection) { FactoryGirl.create(:collection, :public, members: [work]) }

  scenario "displays collection with item, searches" do
    visit collection_path(collection)

    expect(page).to have_text("1 item")
    expect(page).to have_link(title, href: curation_concerns_generic_work_path(work.id))

    # facets there? Can click on them?
    within("div.facets") do
      click_link "Subject"
      click_link(subject)
    end

    # still on page, still see result, with facet limit
    expect(page).to have_current_path(collection_path(collection), only_path: true)
    expect(page).to have_text("1 item")
    expect(page).to have_link(title, href: curation_concerns_generic_work_path(work.id))
    expect(page).to have_css(".constraints-container .constraint-value", text: subject)

    # do a query search too
    within(".chf-collection-search-form") do
      page.fill_in "q", with: title
      click_on class: "collection-submit"
    end
    expect(page).to have_current_path(collection_path(collection), only_path: true)
    expect(page).to have_text("1 item")
    expect(page).to have_link(title, href: curation_concerns_generic_work_path(work.id))
    within(".constraints-container") do
      expect(page).to have_field("q", with: title)
    end
    # not NOT keep the facet limit, fresh search
    expect(page).not_to have_css(".constraints-container .constraint-value", text: subject) # facet limit still there
  end
end

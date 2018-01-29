require 'rails_helper'

# Feature tests are really slow always, and even slower cause it's so slow
# for us to create records in samvera. So we pack a bunch of stuff
# into each scenario, even though that's often said to be not great test design.

RSpec.feature "Collections", js: true do
  let!(:work) { FactoryGirl.create(:work, :with_complete_metadata) }
  let!(:collection) { FactoryGirl.create(:collection, :public, members: [work]) }

  scenario "displays collection with item" do
    visit collection_path(collection)

    expect(page).to have_text("1 item")
    expect(page).to have_link(work.title.first, href: curation_concerns_generic_work_path(work.id))
  end
end

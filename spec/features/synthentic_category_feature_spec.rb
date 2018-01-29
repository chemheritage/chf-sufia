require 'rails_helper'

# aka "featured topics"

RSpec.feature "Synthetic Categories", js: true do
  let(:synthetic_category_defn) { CHF::SyntheticCategory.definitions[:health_and_medicine] }
  let!(:work) { FactoryGirl.create(:generic_work, :with_complete_metadata, subject: [synthetic_category_defn[:subject].first]) }

  scenario "displays category with item" do
    visit synthetic_category_path("health-and-medicine")

    expect(page).to have_css("h1", text: synthetic_category_defn[:title])
    expect(page).to have_text("1 item")
    expect(page).to have_text(synthetic_category_defn[:description])

    expect(page).to have_css(".chf-results-list-item", count: 1)
    expect(page).to have_link(work.title.first, href: curation_concerns_generic_work_path(work.id))
  end
end

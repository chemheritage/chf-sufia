require 'rails_helper'

# Feature tests are really slow always, and even slower cause it's so slow
# for us to create records in samvera. So we pack a bunch of stuff
# into each scenario, even though that's often said to be not great test design.

RSpec.feature "Work form", js: true do
  let(:user) { FactoryGirl.create(:depositor) }
  before do
    login_as(user, :scope => :user)
  end

  [ :title, :additional_title, :language, :bib_num, :artist_name,
      :publisher_name ].each do |attr|
        let(attr) { "Edited #{attr}"}
    end
  let(:date) { "2010"}

  scenario "save new work" do
    visit new_curation_concerns_generic_work_path

    # fields removed from work
    expect(page).not_to have_text('Keyword')
    expect(page).not_to have_text('Date created')

    fill_in("generic_work[title]", with: title)
    fill_in("generic_work[additional_title][]", with: additional_title)
    fill_in("generic_work[language][]", with: additional_title)

    within(".form-group.generic_work_identifier") do
      within first(".field-wrapper") do
        select "Sierra Bib. No."
        fill_in "generic_work[bib_external_id][]", with: bib_num
      end
    end

    within(".form-group.generic_work_maker") do
      within first(".field-wrapper") do
        select "Artist"
        fill_in "generic_work[artist][]", with: artist_name
      end
      click_on "Add another Creator"
      within (".field-wrapper:nth-child(2)") do
        select "Publisher"
        fill_in "generic_work[publisher][]", with: publisher_name
      end
    end

    within(".form-group.generic_work_date_of_work") do
      fill_in "generic_work[date_of_work_attributes][0][start]", with: date
      select "circa", from: "generic_work[date_of_work_attributes][0][start_qualifier]"
    end

    select "Image", from: "generic_work[resource_type][]"

    choose "Your Institution"

    # Save, go to browse page, confirm everything is there
    expect {
      click_button "Save"
      newly_added_work = GenericWork.last
      expect(page).to have_current_path(curation_concerns_generic_work_path(newly_added_work.id), only_path: true)
    }.to change(GenericWork, :count).by(1)

    expect(page).to have_css("h1", text: title)
    expect(page).to have_css(".attribute.resource_type", text: "Image")
    expect(page).to have_text("Sierra Bib. No.: #{bib_num}")
    expect(page).to have_text(artist_name)
    expect(page).to have_text(publisher_name)
    expect(page).to have_text("circa #{date}")
    expect(page).to have_css(".show-permission-badge", text: I18n.t("sufia.institution_name").upcase)
  end
end

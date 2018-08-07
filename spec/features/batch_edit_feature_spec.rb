require 'rails_helper'

RSpec.feature "BatchEditForm", js: true do
  let(:user) { FactoryGirl.create(:depositor) }
  let!(:w1) { FactoryGirl.create(:generic_work, :with_complete_metadata) }
  let!(:w2) { FactoryGirl.create(:generic_work, :with_complete_metadata) }
  let!(:w3) { FactoryGirl.create(:generic_work, :with_complete_metadata) }
  let!(:w4) { FactoryGirl.create(:generic_work, :with_complete_metadata) }
  let!(:w5) { FactoryGirl.create(:generic_work, :with_complete_metadata) }

  scenario "batch edit division, file creator, rights holder and genre" do
    login_as(user, :scope => :user)
    w1, w2, w3, w4, w5 = GenericWork.all
    new_test_work('abc', 'xyz')
    my_work = GenericWork.where(title: ["abc"]).first
    aci = my_work.access_control_id
    ids = GenericWork.all.map { |gw|  gw.id }

    # This is a hack to avoid having to create
    # Fedora access control objects asssociated with the works.
    # The goal here is to get these works to show up on the
    # My Works page, so they can be batch-edited.
    [w1, w2, w3, w4, w5].each do |w|
      w.access_control_id=aci
      w.depositor='depositor@example.com'
      w.save
    end
    edit_batch_single_valued(ids, [1,2,3], 'division',      'Department',     'Center for Oral History')
    edit_batch_single_valued(ids, [0,3,5], 'file_creator',  'File creator',   'Tobias, Gregory')
    edit_batch_single_valued(ids, [3,4],   'rights_holder', 'Rights holder',  'Ludwig van Beethoven', false)
    edit_batch_multi_valued(ids,  [3,4,5], 'genre_string',  'Genre',          'Pesticides',    'Pesticides')
  end

  def new_test_work(title, bib_num)
      visit new_curation_concerns_generic_work_path
      fill_in("generic_work[title]", with: title)
      within(".form-group.generic_work_identifier") do
        within first(".field-wrapper") do
          select "Sierra Bib. No."
          fill_in "generic_work[bib_external_id][]", with: bib_num
        end
      end
      select "Image", from: "generic_work[resource_type][]"
      choose "Your Institution"
      click_button "Save"
  end

  # Batch edits a number of Generic Works, whose indices are specified in which_items,
  # so that their "field" value is set to "value". Checks that the modification
  # did take place, and that the same field on other GenericWorks were not affected.
  def edit_batch_single_valued(ids, which_items, field, field_label, value, dropdown=true)
    visit '/dashboard/works'
    #check values beforehand
    values_beforehand = get_properties(field)
    #make the change
    ids_to_change=ids.values_at(*which_items)
    ids_to_change.each { |id| find_by_id("batch_document_#{id}").click }
    click_button "Edit Selected"
    click_link field_label
    if dropdown
      select value, from: "generic_work[#{field}]"
    else
      fill_in "generic_work[#{field}]", with: value
    end
    click_button "Save changes"
    expect(page).to have_content('Changes Saved', wait:30)

    # check that values were changed as expected
    get_properties(field).each do | id, new_value |
      if ids_to_change.include? id
        expect( new_value).to eq(value)
      else
        expect( new_value).to eq(values_beforehand[id])
      end
    end
  end

  def edit_batch_multi_valued(ids, which_items, field, field_label, value, value_label)
    visit '/dashboard/works'
    values_beforehand = get_properties(field)
    ids_to_change=ids.values_at(*which_items)
    ids_to_change.each { |id| find_by_id("batch_document_#{id}").click }
    click_button "Edit Selected"
    expect(page).to have_content 'Batch Edit Descriptions'
    click_link field_label
    select value_label, :from => field_label
    click_button "Save changes"
    expect(page).to have_content('Changes Saved', wait:30)
    get_properties(field).each do | id, new_value |
      if ids_to_change.include? id
        expect(new_value).to eq([value])
      else
        expect(new_value).to eq(values_beforehand[id])
      end
    end
  end

  def get_properties(field)
    GenericWork.all.map { |gw| [gw.id, gw[field]] }.to_h
  end

end

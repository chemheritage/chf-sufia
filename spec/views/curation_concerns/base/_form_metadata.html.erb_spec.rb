require 'rails_helper'

describe 'curation_concerns/base/_form_metadata.html.erb', type: :view do
  let(:ability) { double }
  let(:user) { stub_model(User) }
  let(:form) do
    CurationConcerns::GenericWorkForm.new(work, ability)
  end

  before do
    view.lookup_context.view_paths.push 'app/views/curation_concerns'
    allow(controller).to receive(:current_user).and_return(user)
  end

  let(:page) do
    view.simple_form_for form do |f|
      render 'curation_concerns/base/form_metadata', f: f
    end
    Capybara::Node::Simple.new(rendered)
  end

  context "for a new object" do
    before { assign(:form, form) }

    let(:work) { GenericWork.new }

    it "renders hidden fields" do
      expect(page).to have_selector "input#generic_work_artist[type='hidden']", visible: false
      inputs_hidden = page.all("input[type='hidden']", visible: false)
      names = inputs_hidden.map { |ih|  ih['name'] }
      expect(names).to include "generic_work[after][]"
      expect(names).to include "generic_work[artist][]"
      expect(names).to include "generic_work[attributed_to][]"
      expect(names).to include "generic_work[author][]"
      expect(names).to include "generic_work[addressee][]"
      expect(names).to include "generic_work[creator_of_work][]"
      expect(names).to include "generic_work[contributor][]"
      expect(names).to include "generic_work[editor][]"
      expect(names).to include "generic_work[engraver][]"
      expect(names).to include "generic_work[interviewee][]"
      expect(names).to include "generic_work[interviewer][]"
      expect(names).to include "generic_work[manner_of][]"
      expect(names).to include "generic_work[school_of][]"
      expect(names).to include "generic_work[manufacturer][]"
      expect(names).to include "generic_work[photographer][]"
      expect(names).to include "generic_work[printer][]"
      expect(names).to include "generic_work[printer_of_plates][]"
      expect(names).to include "generic_work[publisher][]"
      expect(names).to include "generic_work[place_of_interview][]"
      expect(names).to include "generic_work[place_of_manufacture][]"
      expect(names).to include "generic_work[place_of_publication][]"
      expect(names).to include "generic_work[place_of_creation][]"
    end

    it "renders a nested attribute field" do
      expect(page).to have_selector "#generic_work_inscription_attributes_0_location"
      expect(page).to have_selector "#generic_work_inscription_attributes_0_text"
    end

    #TODO: it's not a multiple selector; it's a dropdown with a "more" button. (FIXME)
    it "should render a single-select rights field" do
      expect(page).to have_selector "select[id='generic_work_rights']"
      expect(page).not_to have_selector "select[id='generic_work_rights'][multiple='multiple']"
    end

    it "renders exhibition as a select" do
      expect(page).to have_selector "select[id='generic_work_exhibition']"
    end
    it "renders project as a select" do
      expect(page).to have_content('Science and Disability')
      expect(page).to have_selector "select[id='generic_work_project']"
    end
  end
end

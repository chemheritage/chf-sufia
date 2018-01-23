require 'rails_helper'

# This has really become an integration test now
describe 'curation_concerns/base/show.html.erb' do
  let(:work) do
    FactoryGirl.create(:generic_work).tap do |w|
      w.has_model = ['GenericWork']
      w.human_readable_type = ['Generic Work']
      w.title = ['Super Mario']
      w.additional_title = ['A Super Mario Bros. Adventure']
      w.physical_container = "b2|f3|v4|p5|g234"
      w.identifier = ['object-2004', 'bib-b123456789', 'object-2004-09.003']
      w.creator_of_work = ['Chain Chomp']
      w.contributor = ['Blooper']
      w.after = ['Lakitu']
      w.artist = ['Boo']
      w.author = ['Cheep Cheep']
      w.addressee = ['Koopa']
      w.engraver = ['Thwump']
      w.interviewee = ['Birdo']
      w.interviewer = ['Thwomp']
      w.manufacturer = ['Piranha Plant']
      w.photographer = ['Sparky']
      w.printer_of_plates = ['Shy Guy']
      w.printer = ['Joe Printer']
      w.publisher = ['Hammer Bro']
      w.place_of_interview = ['Underwater']
      w.place_of_manufacture = ['Cloudland']
      w.place_of_publication = ['Pyramid']
      w.place_of_creation = ['Castle']
      w.resource_type = ['Moving Image']
      w.genre_string = ['Platformer']
      w.medium = ['Digital']
      w.extent = ['Infinity']
      w.language = ['Mute']
      w.description = ['Fun']
      w.subject = ['gold coins']
      w.division = 'Nintendo'
      w.exhibition = ['Transmutations']
      w.series_arrangement = ['Ongoing']
      w.related_url = ['example.com']
      w.rights = ['http =//rightsstatements.org/vocab/InC/1.0/']
      w.rights_holder = 'Luigi'
      w.credit_line = ['Courtesy of Science History Institute']
      w.file_creator = 'Miyamoto'
      w.admin_note = ['Mario Kart']
      w.date_of_work_attributes = [{start: "1990-02-09"}]
      w.inscription_attributes = [{location: "side of cartridge", text: "Ravioli"},
        {"location": "On lock", "text": "EAGLE LOCK CO / TERRYVILLE, CONN / U.S.A."}]
      w.additional_credit_attributes = [{role: "photographer", name: "Bowser"}]
      w.save
    end
  end
  let(:solr_document) do
    SolrDocument.new(work.to_solr)
  end

  # ability uses a non-persisted user as a null object, e.g. guest user
  let(:user) { FactoryGirl.build(:user) }
  let(:ability) { Ability.new(user) }
  let(:presenter) do
    CurationConcerns::GenericWorkShowPresenter.new(solr_document, ability).tap do |presenter|
      # our presenter needs a view_context now, custom CHF, so it can run BL presenters too.
      # in a view spec, as we are in, we get a `view`.
      presenter.view_context = view
    end
  end

  # Turn off double verifying for these examples, cause we need to mock helper
  # `search_state`, which is triggering, not really sure why.
  around do |example|
    original = nil
    RSpec.configure do |config|
      config.mock_with :rspec do |mocks|
        original = mocks.verify_partial_doubles?
        mocks.verify_partial_doubles = false
      end
    end

    example.run

    RSpec.configure do |config|
      config.mock_with :rspec do |mocks|
        mocks.verify_partial_doubles = original
      end
    end
  end

  before do
    allow(view).to receive(:search_state).and_return( Blacklight::SearchState.new({}, CatalogController.blacklight_config)  )
    allow(view).to receive(:current_ability).and_return(ability)
    stub_template 'curation_concerns/base/_relationships.html.erb' => ''
    stub_template 'curation_concerns/base/_show_actions.html.erb' => ''
    stub_template 'curation_concerns/base/_representative_media.html.erb' => ''
    stub_template 'curation_concerns/base/_social_media.html.erb' => ''
    stub_template 'curation_concerns/base/_citations.html.erb' => ''
    stub_template 'curation_concerns/base/_items.html.erb' => ''

    assign(:presenter, presenter)
    render
  end

  describe 'local fields display' do
    it 'displays all public fields' do
      expect(rendered).to match /A Super Mario Bros\. Adventure/
      expect(rendered).to match /Box 2, Folder 3, Volume 4, Part 5, Page 234/
      expect(rendered).to match /Chain Chomp/
      expect(rendered).to match /Blooper/
      expect(rendered).to match /Lakitu/
      expect(rendered).to match /Boo/
      expect(rendered).to match /Cheep Cheep/
      expect(rendered).to match /Koopa/
      expect(rendered).to match /Birdo/
      expect(rendered).to match /Thwomp/
      expect(rendered).to match /Piranha Plant/
      expect(rendered).to match /Sparky/
      expect(rendered).to match /Hammer Bro/
      expect(rendered).to match /Underwater/
      expect(rendered).to match /Cloudland/
      expect(rendered).to match /Pyramid/
      expect(rendered).to match /Castle/
      expect(rendered).to match /Moving Image/
      expect(rendered).to match /Platformer/
      expect(rendered).to match /Digital/
      expect(rendered).to match /Infinity/
      expect(rendered).to match /Mute/
      expect(rendered).to match /Fun/
      expect(rendered).to match /gold coins/
      expect(rendered).to match /Nintendo/
      expect(rendered).to match /Transmutations/
      expect(rendered).to match /Ongoing/
      expect(rendered).to match /example.com/
      expect(rendered).to match /rightsstatements\.org/
      expect(rendered).to match /Luigi/
      expect(rendered).to match /Courtesy of Science History Institute/
      expect(rendered).to match /1990-02-09/
      expect(rendered).to match /\(side of cartridge\) "Ravioli"/
      expect(rendered).to match /\(On lock\) "EAGLE LOCK CO \/ TERRYVILLE, CONN \/ U.S.A."/
      expect(rendered).to match /Photographed by Bowser/
      expect(rendered).to match /Thwump/
      expect(rendered).to match /Joe Printer/
      expect(rendered).to match /Shy Guy/
    end
    it "does not display staff fields" do
      expect(rendered).not_to match /Mario Kart/
      expect(rendered).not_to match /Miyamoto/
      expect(rendered).not_to match /Object ID: 2004/
      expect(rendered).not_to match /Sierra Bib. No.: b123456789/
      expect(rendered).not_to match /Object ID: 2004-09.003/
    end
  end

  describe "with staff user" do
    let(:user) { FactoryGirl.create(:user) }

    it "displays staff-only fields" do
      expect(rendered).to match /Object ID: 2004/
      expect(rendered).to match /Sierra Bib. No.: b123456789/
      expect(rendered).to match /Object ID: 2004-09.003/
      expect(rendered).to match /Miyamoto/
      expect(rendered).to match /Mario Kart/
    end
  end

end

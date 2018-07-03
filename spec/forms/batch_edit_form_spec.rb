require 'rails_helper'

RSpec.describe BatchEditForm do
  let(:model) { GenericWork.new }
  let(:work1) { FactoryGirl.create :generic_work, title: ["title 1"], language: ['en'], contributor: ['contributor1'], description: ['description1'], rights: ['rights1'], subject: ['subject1'], identifier: ['id1'], related_url: ['related_url1'], visibility: visibility1 }
  let(:work2) { FactoryGirl.create :generic_work, title: ["title 2"], publisher: ['Rand McNally'], language: ['en'], resource_type: ['bar'], contributor: ['contributor2'], description: ['description2'], rights: ['rights2'], subject: ['subject2'], identifier: ['id2'], related_url: ['related_url2'], visibility: visibility2 }
  let(:visibility1) { "authenticated" }
  let(:visibility2) { "restricted" }
  let(:batch) { [work1.id, work2.id] }
  let(:form) { described_class.new(model, ability, batch) }
  let(:ability) { Ability.new(user) }
  let(:user) { FactoryGirl.build(:user, display_name: 'Jill Z. User') }

  describe "#terms" do
    subject { form.terms }
    it do
      is_expected.to eq [
        :division,
        :rights_holder,
        :file_creator,
        :additional_title,
        :identifier,
        :admin_note,
        :resource_type,
        :subject, :language,
        :related_url,
        :after,
        :artist,
        :author,
        :addressee,
        :creator_of_work,
        :contributor,
        :engraver,
        :interviewee,
        :interviewer,
        :manner_of,
        :manufacturer,
        :photographer,
        :printer,
        :printer_of_plates,
        :publisher,
        :place_of_interview,
        :place_of_manufacture,
        :place_of_publication,
        :place_of_creation,
        :exhibition,
        :source,
        :genre_string,
        :medium,
        :extent,
        :series_arrangement,
        :rights
      ]
    end
  end

  describe "#model" do
    it "combines the models in the batch" do
      expect(form.model.contributor).to match_array ["contributor1", "contributor2"]
      expect(form.model.resource_type).to match_array ["bar"]
      expect(form.model.rights).to match_array ["rights1", "rights2"]
      expect(form.model.publisher).to match_array ["Rand McNally"]
      expect(form.model.subject).to match_array ["subject1", "subject2"]
      expect(form.model.language).to match_array ["en"]
      expect(form.model.identifier).to match_array ["id1", "id2"]
      expect(form.model.related_url).to match_array ["related_url1", "related_url2"]
    end

    describe "when works have different visibilities" do
      it "uses default visibility" do
        expect(form.model.visibility).to eq "open"
      end
    end
    describe "when works have the same visibility" do
      let(:visibility1) { "authenticated" }
      let(:visibility2) { "authenticated" }

      it "uses the works' visibility" do
        expect(form.model.visibility).to eq "authenticated"
      end
    end
  end
end

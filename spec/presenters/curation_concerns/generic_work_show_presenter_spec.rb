require 'spec_helper'

describe CurationConcerns::GenericWorkShowPresenter do
  let(:request) { double }

  let(:ability) { nil }
  let(:presenter) { described_class.new(solr_document, ability, request) }


  describe "#representative_file_id" do
    let(:solr_document) { SolrDocument.new(work.to_solr) }
    let(:ability) { double "Ability" }
    let(:work) do
      FactoryGirl.create(:generic_work).tap do |w|
        w.ordered_members << fileset
        w.ordered_members << fileset2
        w.representative = fileset2
        w.thumbnail = fileset2
        w.save
      end
    end
    let(:fileset) { FactoryGirl.create(:file_set, title: ["adventure_time.txt"], content: StringIO.new("Algebraic!")) }
    let(:fileset2) { FactoryGirl.create(:file_set, title: ["adventure_time_2.txt"], content: StringIO.new("Mathematical!")) }

    it "returns representative fileset's original file id" do
      expect(presenter.representative_file_id).to be_a String
      expect(presenter.representative_file_id).to eq fileset2.original_file.id
    end
  end


  describe "#viewable_member_presenters" do
    let(:public_work_with_one_file) do
      work = FactoryGirl.build(:work, visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC)
      work.ordered_members << FactoryGirl.create(:file_set, visibility: file_visibility)
      work.save!
      work
    end

    let(:solr_document) { SolrDocument.new(public_work_with_one_file.to_solr) }

    describe "with admin user"  do
      let(:user) { FactoryGirl.create(:user, :admin) }
      let(:ability) { Ability.new(user) }

      describe "protected file" do
        let(:file_visibility) { Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED }
        it "reveals protected file" do
          expect(presenter.viewable_member_presenters.length).to eq 1
        end
      end

      describe "public file" do
        let(:file_visibility) { Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC }
        it "reveals public file" do
          expect(presenter.viewable_member_presenters.length).to eq 1
        end
      end
    end

    describe "with non-logged in user" do
      let(:ability) { Ability.new(nil) }

      describe "protected file" do
        let(:file_visibility) { Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED }
        it "does not reveal protected file" do
          expect(presenter.viewable_member_presenters.length).to eq 0
        end
      end

      describe "public file" do
        let(:file_visibility) { Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC }
        it "reveals public file" do
          expect(presenter.viewable_member_presenters.length).to eq 1
        end
      end
    end
  end
end

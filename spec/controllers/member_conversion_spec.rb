require 'rails_helper'
RSpec.describe MemberConversionController, type: :controller do
  let(:user) { FactoryGirl.create(:user) }

  let(:parent_work) {  FactoryGirl.create(
      :work,
      :fake_public_image,
      creator: ["Fred"],
      title: ["abc"],
      language: ['en'],
      id: 'parent123'
    ) }

    let!(:collection) { FactoryGirl.create(
      :public_collection,
      members: [parent_work]
    ) }

    before do
      sign_in user
    end

    context "a generic work with a file attached to it." do
    before do
        allow(controller.current_ability).to receive(:can?).and_return(true)
    end

    it "promotes a fileset to a child work, then back to a fileset" do
      # Note that a member fileset was already created,
      # conveniently enough, when we created the parent work.

      file_set = parent_work.ordered_members.to_a.first
      post :to_child_work, params: {  parentid: parent_work.id, filesetid: file_set.id }
      parent_work.reload
      collection.reload

      expect(GenericWork.all.to_a.count).to eq 2
      expect(parent_work.members.to_a.count).to eq 1
      expect(parent_work.ordered_members.to_a.count).to eq 1
      new_child_work = parent_work.members.first
      expect(new_child_work.class.name ).to eq "GenericWork"
      expect(response).to be_redirect
      expect(parent_work.thumbnail_id).to eq  new_child_work.id
      expect(parent_work.representative_id).to eq  new_child_work.id

      # the new child work should inherit its collection from its parent.
      expect(collection.members.to_a.count).to eq 2
      expect(collection.members.to_a).to include parent_work
      expect(collection.members.to_a).to include new_child_work


      # all parent's permissions should be transferred to the new child work.
      # Otherwise stated, if you subtract the new child's permissions
      # from those of the parent, you should get an empty set.
      expect(
        (
          parent_work   .permissions.map(&:to_hash) -
          new_child_work.permissions.map(&:to_hash)
         ).count
      ).to eq 0

      # all the garden-variety metadata should get copied as well, of course.
      attrs_to_copy = parent_work.attributes.sort.map { |a| a[0] }
      attrs_to_copy -= ['id', "title", 'lease_id', 'embargo_id', 'head', 'tail',
        'access_control_id', 'thumbnail_id', 'representative_id' ]
      attrs_to_copy.each do |attr|
        expect(parent_work[attr]).to eq new_child_work[attr]
      end

      # However, the new child work's title should come from the fileset:
      expect(new_child_work.title).to eq ["sample.jpg"]

      # Now run the procedure in reverse: demote the new child work to a fileset.
      post :to_fileset, params: {
        parentworkid: parent_work.id,
        childworkid: new_child_work.id
      }

      expect(response).to be_redirect

      parent_work.reload
      collection.reload

      # This gets rid of the child work
      expect { new_child_work.reload }.to raise_error(Ldp::Gone)

      #and re-attaches the fileset directly to the parent.
      expect(GenericWork.all.to_a.count).to eq 1
      expect(parent_work.members.to_a.count).to eq 1
      expect(parent_work.ordered_members.to_a.count).to eq 1
      expect(parent_work.members.first).to eq file_set
      expect(parent_work.thumbnail_id).to eq file_set.id
      expect(parent_work.representative_id).to eq file_set.id

    end
  end
end
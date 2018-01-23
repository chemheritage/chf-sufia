require 'rails_helper'


RSpec.feature "Search builder overrides", js: true do
  describe "public domain filter" do
    let!(:public_domain) { FactoryGirl.create(:generic_work, :with_complete_metadata, title: ["testrecord public"], rights: ['http://creativecommons.org/publicdomain/mark/1.0/']) }
    let!(:not_public_domain) { FactoryGirl.create(:generic_work, :with_complete_metadata, title: ["testrecord notpublic"], rights: ['http://rightsstatements.org/vocab/InC/1.0/']) }

    it "limits to public domain only" do
      visit root_path
      fill_in "q", with: "testrecord"
      check "filter_public_domain"
      click_button "Go"

      expect(page).to have_current_path(search_catalog_path, only_path: true)
      expect(page).to have_text("testrecord public")
      expect(page).not_to have_text("testrecord notpublic")
    end
  end

  describe "fields limited to admin search", js: true do
    let!(:admin_only_field) { FactoryGirl.create(:generic_work, :with_complete_metadata, title: ["with admin only"], admin_note: ["admin_only_term"]) }

    describe "with non-logged in user" do
      it "can't find record" do
        visit search_catalog_path(q: "admin_only_term")
        expect(page).not_to have_text("with admin only")
      end
    end

    describe "with staff user" do
      before do
        user = FactoryGirl.create(:staff_user)
        login_as(user, :scope => :user)
      end

      it "can find record" do
        visit search_catalog_path(q: "admin_only_term")
        expect(page).to have_text("with admin only")
      end
    end
  end



end

require 'rails_helper'


RSpec.feature "sitemap generator", js: false do
  # reset sitemap adapter to not send to s3, too hard to test for now
  around(:each) do |example|
    $force_default_sitemap_adapter = true
    example.run
    $force_default_sitemap_adapter = false
  end

  before(:all) do
    $sitemap_adapter = nil
    Rails.application.load_tasks

    spec = Gem::Specification.find_by_name 'sitemap_generator'
    load "#{spec.gem_dir}/lib/tasks/sitemap_generator_tasks.rake"
  end

  before(:each) do
     # fits may not be installed on travis, and is slow. Try to keep it from happening.
     # Alternately, if we really want to install fits on travis:
     # https://github.com/ucsblibrary/alexandria/blob/master/.travis.yml#L24-L27
    allow_any_instance_of(CharacterizeJob).to receive(:perform).and_return(nil)
  end

  let!(:public_work) { FactoryGirl.create(:public_work, :real_public_image) }
  let(:public_work_url) { "https://digital.sciencehistory.org/works/#{public_work.id}" }

  let!(:private_work) { FactoryGirl.create(:private_work) }
  let(:private_work_url) { "https://digital.sciencehistory.org/works/#{private_work.id}" }

  it "smoke tests" do
    Rake::Task["sitemap:create"].invoke

    Zlib::GzipReader.open(Rails.root + "public/sitemap/sitemap.xml.gz") do |gz_stream|
      xml = Nokogiri::XML(gz_stream.read)

      expect(
        xml.at_xpath("sitemap:urlset/sitemap:url/sitemap:loc[contains(text(), \"#{public_work_url}\")]", sitemap: "http://www.sitemaps.org/schemas/sitemap/0.9")
      ).to be_present

      expect(
        xml.at_xpath("sitemap:urlset/sitemap:url/sitemap:loc[contains(text(), \"#{private_work_url}\")]", sitemap: "http://www.sitemaps.org/schemas/sitemap/0.9")
      ).not_to be_present
    end
  end
end

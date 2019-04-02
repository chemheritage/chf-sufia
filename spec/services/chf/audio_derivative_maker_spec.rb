require 'rails_helper'
RSpec.describe CHF::AudioDerivativeMaker do

  let(:adm) do
    allow_any_instance_of(CHF::CreateDerivativesOnS3Service).to receive(:s3_bucket!).and_return(nil)
    file_info = {
      :file_id=>"asd", :file_checksum=>"asd",
      :file_set=>FactoryGirl.create(:file_set),
      :file_set_content_type=>"audio/mpeg",
    }
    puts "In first part"
    CHF::AudioDerivativeMaker.new(file_info, false)
  end

  before do
    byebug
    puts "In second part"

    #allow_any_instance_of(CHF::CreateDerivativesOnS3Service).to receive(:s3_bucket!).and_return(nil)

    allow(adm).to receive(:s3_bucket!).and_return(nil) #TODO remove.
    allow(adm).to receive(:s3_obj_for_this_file).and_return(nil)
    allow(adm).to receive(:report_success).and_return(nil)
    allow(adm).to receive(:we_need_this_derivative?).and_return(true)
    allow(adm).to receive(:upload_file_to_s3).and_return(true)
    allow(adm).to receive(:download_file_from_fedora).and_return(Rails.root.join('spec/fixtures/sample.mp3'))
  end

  after do
    FileUtils.rm adm.instance_variable_get(:@working_dir), :force => true
  end

  it "creates derivatives" do
    adm.create_and_upload_derivatives()
    derivs = Dir.entries(adm.instance_variable_get(:@working_dir))
    expect(derivs).to eq([".", "..", "standard_webm.webm", "standard_mp3.mp3"])
  end
end

require 'rails_helper'

describe ImageServiceHelper do
  describe "#iiif_info_url" do
    before do
      allow(CHF::Env).to receive(:lookup).with(:image_server).and_return('riiif')
    end

    context "using localhost" do
      it "provides relative path" do
        allow(CHF::Env).to receive(:lookup).with(:public_riiif_url).and_return(nil)
        expect(helper.iiif_info_url('file_id')).to eq "/image-service/file_id/info.json"
      end
    end

    context "configured for remote box" do
      context "correct config supplied" do
        before do
          allow(CHF::Env).to receive(:lookup).with(:public_riiif_url).and_return('//example.com')
        end
        it "provides full riiif url" do
          expect(helper.iiif_info_url('file_id')).to eq "//example.com/image-service/file_id/info.json"
        end
        it "provides full cantaloupe url" do
          allow(CHF::Env).to receive(:lookup).with(:image_server).and_return('cantaloupe')
          expect(helper.iiif_info_url('file_id')).to eq "//example.com/iiif/2/file_id/info.json"
        end
      end
      context "bare host supplied" do
        it "raises" do
          allow(CHF::Env).to receive(:lookup).with(:public_riiif_url).and_return('example.com')
          expect{ helper.iiif_info_url('file_id') }.to raise_error(RuntimeError)
        end
      end
    end
  end

end

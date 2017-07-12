require 'rails_helper'

describe RiiifHelper do
  describe "#riiif_info_url" do
    context "riiif uses localhost" do
      it "provides relative path" do
        allow(CHF::Env).to receive(:lookup).with(:public_riiif_url).and_return(nil)
        expect(helper.riiif_info_url('file_id')).to eq "/image-service/file_id/info.json"
      end
    end

    context "riiif configured for remote box" do
      context "correct config supplied" do
        it "provides full url" do
          allow(CHF::Env).to receive(:lookup).with(:public_riiif_url).and_return('//example.com')
          expect(helper.riiif_info_url('file_id')).to eq "//example.com/image-service/file_id/info.json"
        end
      end
      context "bare host supplied" do
        it "raises" do
          allow(CHF::Env).to receive(:lookup).with(:public_riiif_url).and_return('example.com')
          expect{ helper.riiif_info_url('file_id') }.to raise_error(RuntimeError)
        end
      end
    end
  end

end

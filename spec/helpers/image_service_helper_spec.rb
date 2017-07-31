require 'rails_helper'

describe ImageServiceHelper do
  describe "#iiif_info_url" do

    context "info.json" do
      it "works with localhost/port" do
        allow(CHF::Env).to receive(:lookup).with(:iiif_public_url).and_return('http://localhost:3000/image-service')
        expect(helper.iiif_info_url('file_id')).to eq "http://localhost:3000/image-service/file_id/info.json"
      end

      it "works with schemaless host" do
        allow(CHF::Env).to receive(:lookup).with(:iiif_public_url).and_return('//localhost:3000/image-service')
        expect(helper.iiif_info_url('file_id')).to eq "//localhost:3000/image-service/file_id/info.json"
      end

      context "with a cantaloupe host" do
        it "works when no trailing slash" do
          allow(CHF::Env).to receive(:lookup).with(:iiif_public_url).and_return('http://example.com:8182/iiif/2')
          expect(helper.iiif_info_url('file_id')).to eq "http://example.com:8182/iiif/2/file_id/info.json"
        end
        it "works when yes trailing slash" do
          allow(CHF::Env).to receive(:lookup).with(:iiif_public_url).and_return('http://example.com:8182/iiif/2/')
          expect(helper.iiif_info_url('file_id')).to eq "http://example.com:8182/iiif/2/file_id/info.json"
        end
      end

      it "raises on bare host" do
        allow(CHF::Env).to receive(:lookup).with(:iiif_public_url).and_return('example.com')
        expect{ helper.iiif_info_url('file_id') }.to raise_error(RuntimeError)
      end
    end
  end

end

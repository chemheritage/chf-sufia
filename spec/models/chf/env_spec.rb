require 'spec_helper'

describe CHF::Env do
  let(:test_key) { :some_key }
  let(:env_value) { "env_value" }
  let(:conf_value) { "conf_value" }
  let(:default_value) { "default_value"}
  let(:instance) do
    CHF::Env.new.tap do |e|
      e.define_key test_key, default: default_value
    end
  end

  describe "from ENV" do
    before do
      stub_const('ENV', ENV.to_hash.merge(test_key.to_s.upcase => env_value))
      allow(instance).to receive(:load_yaml_file).and_return(test_key.to_s => conf_value)
    end

    it "takes priority" do
      expect(instance.lookup(test_key)).to eq(env_value)
    end
  end

  describe "from conf_file" do
    before do
      allow(instance).to receive(:load_yaml_file).and_return(test_key.to_s => conf_value)
    end
    it "returns from conf file" do
      expect(instance.lookup(test_key)).to eq conf_value
    end
  end

  describe "from default" do
    it "returns simple default" do
      expect(instance.lookup(test_key)).to eq(default_value)
    end
    describe "with lambda" do
      before do
        instance.define_key test_key, default: -> { "default_from_lambda" }
      end
      it "returns lambda result" do
        expect(instance.lookup(test_key)).to eq("default_from_lambda")
      end
    end
  end

  describe "with boolean values in config file" do
    before do
      instance.define_key "boolean_value", default: true
    end
    it "falls through to default true" do
      expect(instance.lookup("boolean_value")).to eq true
    end

    describe "false in config file" do
      before do
        allow(instance).to receive(:load_yaml_file).and_return("boolean_value" => false)
      end

      it "retrieves false value from conf" do
        expect(instance.lookup("boolean_value")).to eq false
      end
    end
  end
end

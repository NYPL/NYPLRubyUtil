require 'spec_helper'


KmsClient = NYPLRubyUtil::KmsClient


describe KmsClient do

  describe :config do
    test_value = "test_value"
    before do
      allow(Aws::KMS::Client).to receive(:new).and_return(test_value)
      KmsClient.class_variable_set(:@@kms, nil)
    end

    it "should set @kms" do
      client = KmsClient.new
      expect(client.instance_variable_get(:@kms)).to equal(test_value)
    end

    it "should pass empty hash to aws_kms_client in case no inputs" do
      expect(KmsClient).to receive(:aws_kms_client).with({})
      client = KmsClient.new
    end

    it "should pass empty hash to aws_kms_client in case nil input" do
      expect(KmsClient).to receive(:aws_kms_client).with({})
      client = KmsClient.new(nil)
    end

    it "should pass options to aws_kms_client in case options are passed" do
      test_options = Hash.new {|h,k| h[k] = "fake"}
      expect(KmsClient).to receive(:aws_kms_client).with(test_options)
      client = KmsClient.new
    end
  end

  describe :decrypt do
    kms_client = KmsClient.new
    cipher = Base64.encode64 "cipher"
    before do
      allow(kms_client.instance_variable_get(:@kms)).to receive(:decrypt).and_return({
        plaintext: "plain"
        })
    end

    it "should pass base64-decoded ciphertext to @kms" do
      blob = {ciphertext_blob: "cipher"}
      expect(kms_client.instance_variable_get(:@kms)).to receive(:decrypt).with(blob)
      kms_client.decrypt(cipher)
    end

    it "should return the plaintext" do
      plain = kms_client.decrypt(cipher)
      expect(plain).to eq("plain")
    end
  end

  describe :aws_kms_client do

    params = {
      region: 'us-east-1',
      stub_responses: ENV['APP_ENV'] == 'test'
    }
    kms = nil

    it 'should merge the options to standard params and create new aws client if none exists' do
      expect(Aws::KMS::Client).to receive(:new).with(params)
      kms = KmsClient.aws_kms_client({})
      expect(KmsClient.class_variable_get(:@@kms)).to eq(kms)
    end

    it 'should return existing aws client if one exists' do
      kms = KmsClient.aws_kms_client({})
      expect(KmsClient.aws_kms_client({})).to eq(kms)
    end
  end
end

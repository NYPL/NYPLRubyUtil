require 'spec_helper'
require 'net/http'
require_relative '../../lib/platform_api_client'
require_relative '../../lib/kms_client'

describe PlatformApiClient do

  describe "get" do
    before do
      ENV['NYPL_OAUTH_ID'] = 'oauth_id'
      ENV['NYPL_OAUTH_SECRET'] = 'oauth_secret'
      ENV['NYPL_OAUTH_URL'] = 'http://www.fake_oauth.com/'
      ENV['PLATFORM_API_BASE_URL'] = 'http://www.fake-platform.com/'
      mock_kms_client = double
      mock_logger = double
      $logger = mock_logger
      allow(mock_logger).to receive(:debug).and_return(nil)
      allow(KmsClient).to receive(:new).and_return(mock_kms_client)
      allow(mock_kms_client).to receive(:decrypt).and_return('decrypted')
    end


    it "should retry in case of 401 response" do
      stub_request(:any, /oauth/).to_return(body: { "access_token" => "token" }.to_json, status: 200)
      stub_request(:any, /platform/).to_return(
        { body: "not authenticated".to_json, status: 401 },
        { body: "success".to_json, status: 200 }
      )
      platform_api_client = PlatformApiClient.new
      expect(platform_api_client.get('fake_path')).to eql("success")
    end
  end


end

require 'net/http'
require 'net/https'
require 'uri'

require_relative 'kms_client'

class PlatformApiClient
  attr_reader :authenticated, :client_id, :client_secret, :error_options, :oauth_site
  attr_accessor :access_token

  def initialize(options = {})
    raise 'Missing config: NYPL_OAUTH_ID is unset' if ENV['NYPL_OAUTH_ID'].nil? || ENV['NYPL_OAUTH_ID'].empty?
    raise 'Missing config: NYPL_OAUTH_SECRET is unset' if ENV['NYPL_OAUTH_SECRET'].nil? || ENV['NYPL_OAUTH_SECRET'].empty?

    kms_client = KmsClient.new(options[:kms_options])
    @client_id = kms_client.decrypt(ENV['NYPL_OAUTH_ID'])
    @client_secret = kms_client.decrypt(ENV['NYPL_OAUTH_SECRET'])

    @oauth_site = ENV['NYPL_OAUTH_URL']
    @authenticated = options[:authenticated] || true
    @error_options = default_errors.merge(options[:errors] || {})
  end

  def get (path, transaction_data = {})

    authenticate! if authenticated

    uri = URI.parse("#{ENV['PLATFORM_API_BASE_URL']}#{path}")

    $logger.debug "Getting from platform api", { uri: uri }

    begin
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{access_token}" if authenticated
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme === 'https') do |http|
        http.request(request)
      end

      $logger.debug "Got platform api response", { code: response.code, body: response.body }

      parse_json_response response, path, transaction_data

    rescue Exception => e
      raise StandardError.new(e), "Failed to retrieve #{path} #{e.message}"
    end
  end

  private

  def parse_json_response (response, path, transaction_data = {})
    code = response.code.to_i
    if code < 400
      JSON.parse(response.body)
    elsif error_options[code]
      instance_exec(response, path, transaction_data, &error_options[code])
    else
      raise "Error interpretting response for path #{path}: (#{response.code}): #{response.body}"
      {}
    end
  end

  # Authorizes the request.
  def authenticate!
    $logger.debug('authenticating')
    # NOOP if we've already authenticated
    return nil if ! access_token.nil?

    uri = URI.parse("#{oauth_site}oauth/token")
    request = Net::HTTP::Post.new(uri)
    request.basic_auth(client_id, client_secret)
    request.set_form_data(
      "grant_type" => "client_credentials"
    )

    req_options = {
      use_ssl: uri.scheme == "https",
      request_timeout: 500
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end

    if response.code == '200'
      self.access_token = JSON.parse(response.body)["access_token"]
      $logger.debug('got token')
    else
      $logger.debug('no token')
      nil
    end
  end

  def default_errors
    {
      401 => lambda do |response, path, transaction_data = {}|
        transaction_data[:try_count] ||= 0
        if transaction_data[:try_count] < 1
          # Likely an expired access-token; Wipe it for next run
          transaction_data[:try_count] += 1
          self.access_token = nil
          get(path, transaction_data)
        else
          raise "Error interpretting response for path #{path}: (#{response.code}): #{response.body}"
        end
      end
    }
  end

end

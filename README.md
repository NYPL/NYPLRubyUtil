
# NYPLRubyUtil

This gem contains several utility classes for common tasks in Ruby applications deployed to AWS.

## Installation

`gem install nypl_ruby_util`

## API

### Logging

NYPLRubyUtil::NyplLogFormatter

(description to come)

### HTTP Requests to Sierra

NYPLRubyUtil::SierraApiClient

#### Configuration

Example configuration:

```
client = NYPLRubyUtil::SierraApiClient.new({
  base_url: "https://[fqdn]/iii/sierra-api/v5", # Defaults to ENV['SIERRA_API_BASE_URL']
  client_id: "client-id", # Defaults to ENV['SIERRA_OAUTH_ID']
  client_secret: "client-secret", # Defaults to ENV['SIERRA_OAUTH_SECRET']
  oauth_url: "https://[fqdn]/iii/sierra-api/v3/token", # Defaults to ENV['SIERRA_OAUTH_URL'],
  log_level: "debug" # Defaults to 'info'
})
```

#### Requests

Example GET:

```ruby
bib_response = sierra_client.get 'bibs/12345678'
bib = bib_response.body
```

Example POST:

```ruby
check_login = sierra_client.post 'patrons/validate', { "barcode": "1234", "pin": "6789" }
valid = check_login.success?
invalid = check_login.error?
```

Note that only GET and POST are supported at writing.

#### Responses

Because of the variety of HTTP status codes and "Content-Type"s returned by the Sierra REST API, the Sierra API Client makes few assumptions about the response. All calls return a `SierraApiResponse` object with the following methods:

 * `code`: HTTP status code as an Integer (e.g. `200`, `500`)
 * `success?`: True if `code` is 2** or 3**
 * `error?`: True if `code` is >= `400`
 * `body`: The returned body. If response header indicates it's JSON, it will be a `Hash`.
 * `response`: The complete [`Net::HTTPResponse`](https://ruby-doc.org/stdlib-2.7.1/libdoc/net/http/rdoc/Net/HTTPResponse.html) object for inspecting anything else you like.

In the spirit of agnosticism, the client will not intentionally raise an error when it encounters an error HTTP status code. Client will only raise an error when the request could not be carried out as specified and should be retried, that is:
 - Network failure
 - Invalid token error (401)

### HTTP Requests to Platform

NYPLRubyUtil::PlatformApiClient

(description to come)

### Avro Encoding and Decoding

NYPLRubyUtil::NYPLAvro

(description to come)

### KMS Encryption and Decryption

NYPLRubyUtil::KmsClient

(description to come)

## Contributing

This repo uses a single, versioned `master` branch.

 * Create feature branch off `master`
 * Compute next logical version and update `README.md`, `CHANGELOG.md`, & `nypl_ruby_util.gemspec`
 * Create PR against `master`
 * After merging the PR, git tag `master` with new version number.


# NYPLRubyUtil

This gem contains several utility classes for common tasks in Ruby applications deployed to AWS.

## Version

`0.0.3`

## Installation

`gem install nypl_ruby_util`

## API

### Logging

`NYPLRubyUtil::NyplLogFormatter`

#### Usage

```ruby
require 'nypl_log_formatter'

my_logger = NyplLogFormatter.new('path/to/file.log')
my_logger.info('this will log JSON')
my_logger.warn('So will this')

# Contents of file.log
  # Logfile created on 2018-01-17 15:51:31 -0500 by logger.rb/61378
  #{"level":"INFO","message":"this will log JSON","timestamp":"2018-01-17T15:51:53.481-0500"}
  #{"level":"WARN","message":"So will this","timestamp":"2018-01-17T15:51:54.279-0500"}
```

#### Instantiating A Logger

The constructor (and all other methods, really) of NyplLogFormatter are the same as a Logger.
Which means you can do EVERYTHING you can with a `Logger`, in the same way.
That includes:

* Setting Log level
* Using `STDOUT` instead of a file.
* Setting log rotation.

For more info see your ruby version's documentation for the `Logger` class.

#### Logging Additional Key/Value Pairs

You can pass a second argument, a Hash that will end up as keys/values in the
logged JSON.

```ruby
logger = NYPLRubyUtil::NyplLogFormatter.new('path/to/file.log')

logger.error(
  'Something went wrong',
  user: {email: 'simon@example.com', name: 'simon'},
  permissions: ['admin', 'good-boy']
)

# Contents of file.log
  # Logfile created on 2018-01-17 15:51:31 -0500 by logger.rb/61378
  #{"level":"ERROR","message":"Something went wrong","timestamp":"2018-02-07T16:47:22.017-0500","user":{"email":"simon@example.com","name":"simon"},"permissions":["admin","good-boy"]}

```

#### Logging Levels

You can set logging threshold to control what severity of log is written either in the initializer:

```
Application.logger = NYPLRubyUtil::NyplLogFormatter.new(STDOUT, level: 'info')
```

Or using the `level=` setter:

```
Application.logger.level = 'info'
```

See [Logger notes on supported levels](https://github.com/ruby/logger/blob/78725003c190275f2e8a7c84af038c3c6d9e8209/lib/logger.rb#L168-L191)

### HTTP Requests to Sierra

`NYPLRubyUtil::SierraApiClient`

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

`NYPLRubyUtil::PlatformApiClient`

#### Configuration

Required environment variables:

`NYPL_OAUTH_ID`, encrypted
`NYPL_OAUTH_SECRET`, encrypted
`NYPL_OAUTH_URL`
`PLATFORM_API_BASE_URL`

Also requires `$logger` to be set

Allows `kms_options` to be set to a hash, which will pass that hash on to the client's
internal decryption object. For example:

```
plat = NYPLRubyUtil::PlatformApiClient.new(kms_options: { profile: 'nypl-digital-dev' })
```

will initialize a client that can use `nypl-digital-dev` creds

Allows `errors` to be set to a hash of numbers pointing to procs. In case the client receives a response from Platform with one of these error codes, it will call the corresponding proc with arguments (response, path). The only error handling set by default is to retry once in case of a 401.

Example:

```plat =  NYPLRubyUtil::PlatformApiClient.new(errors: { 500 => lambda do |resp, path| puts 500, resp, path })
```

#### Requests

Only get requests are supported currently. Example:

```
plat.get('bibs')
```

Returns a hash representing a the body of the response parsed from json, if the response code is < 400. Otherwise raises an exception


### Avro Encoding and Decoding

`NYPLRubyUtil::NYPLAvro`

#### Configuration
Initialize the client by name of avro, e.g.,

```
avro_client = NYPLRubyUtil::NYPLAvro.by_name('HoldRequestResult')
```

#### Usage

To encode, pass the hash to the avro_client, e.g.:

```
test_message =  { jobId: "123", success: true, Error: { message: "Test message", type: "debug" }, holdRequestId:12345 }
encoded = avro_client.encode(test_message)
```

to decode, pass the encoded string to the avro_client, e.g.:

```
decoded = avro_client.decode(encoded)
```

Both `encode` and `decode` have an optional variable `base64`.

`base64` is a boolean that defaults to true, and determines whether to base64 encode/decode the input/output

### KMS Encryption and Decryption

`NYPLRubyUtil::KmsClient`

A thin wrapper around `aws-sdk-kms`

#### Initializing

`kmsclient = NYPLRubyUtil::KmsClient.new(options)`

Will set `us-east-1` as the region by default. A useful option to pass locally is `{ profile: 'nypl-digital-dev' }`. Accepts any options that `AWS::KMS::Client` will accept.

#### Decrypting:

`kmsclient.decrypt(encoded_string)`

Assumes the encoded string is base64 encoded


### Kinesis Writes

`NYPLRubyUtil::KinesisClient`

#### Initializing

`kinesis_client = NYPLRubyUtil::KinesisClient.new(config)`

The currently used parameters for config are:

`schema_string` The name of the avro for encoding the data. Will use the NYPL Avro client described above

`stream_name` The name of the Kinesis stream

#### Usage

`kinesis_client << json_message`

Will encode the `json_message` using the configured avro and write to the configured kinesis stream

### Deploying In CI/CD

`NYPLRubyUtil` contains a class `DeployHelper` to help with some missing functionality in travis. This can be used to make sure vpc configuration, environment variables, event triggers, and layers are properly deployed as part of CI/CD.

#### Usage

In your `rakefile`, require the `NYPLRubyUtil` gem.
Add the following:

```
desc 'Update lambda layers, environment_variables, vpc, and events'
task :set_config do
    deploy_helper = NYPLRubyUtil::DeployHelper.new
    deploy_helper.update_lambda_configuration
    deploy_helper.update_event
end
```

Then in travis:

```
after_deploy:
- rake set_config
```

Add configuration using the following format:

```

- provider: lambda
  function_name: Name-env
  layers:
  - Layer1
  - Layer2
  ...
  vpc_config:
    subnet_ids:
    - subnet1
    - subnet2
    - ...
    security_group_ids:
    - id1
    ...
  environment:
    variables:
      VAR_1: value1
      VAR2: value2
      ...
  event:
    schedule_expression: rate(24 hours)
    OR
    event:
    event_source_arn: arn
    batch_size: ...
    maximum_record_age_in_seconds: ...
    bisect_batch_on_function_error: ...
    maximum_retry_attempts: ...
    starting_position: ...
  access_key_id: [e.g. "$AWS_ACCESS_KEY_ID_PRODUCTION"]
  secret_access_key: [e.g. "$AWS_SECRET_ACCESS_KEY_PRODUCTION"]
  on:
    branch: env

```

NB: There are two different kinds of events that are supported.
1. Cron jobs. You can just put the schedule expression directly in travis and travis will create the cron job.
2. Kinesis events. You have to have an arn for an existing kinesis event for this one, and travis will connect the lambda
to the right stream

Also note that this utility is only set up currently to support one event source at a time, and will delete existing event sources if there are others.

## Running Tests
Step 1: Write the Tests

Step 2: Run them

## Contributing

This repo uses a single, versioned `master` branch.

 * Create feature branch off `master`
 * Compute next logical version and update `README.md`, `CHANGELOG.md`, & `nypl_ruby_util.gemspec`
 * Create PR against `master`
 * After merging the PR, git tag `master` with new version number.

Gem::Specification.new do |s|
  s.name = "nypl_ruby_util"
  s.version = "0.0.4"
  s.date = "2020-09-08"
  s.description = "A repository of common utilities for NYPL Ruby application"
  s.summary = "A repository of common utilities for NYPL Ruby application"
  s.add_runtime_dependency "avro",
    ["= 1.10.0"]
  s.add_runtime_dependency "aws-sdk-kinesis",
    ["= 1.26.0"]
  s.add_runtime_dependency "aws-sdk-kms",
    ["= 1.36.0"]
  s.add_runtime_dependency "aws-sdk-lambda"
  s.add_runtime_dependency "aws-sdk-cloudwatchevents"
  s.add_runtime_dependency "nypl_log_formatter",
    ["= 0.1.3"]
  s.add_runtime_dependency "nypl_sierra_api_client",
    ["= 1.0.3"]
  s.author = ["Daniel Appel"]
  s.files = ["lib/nypl_ruby_util.rb",
    "lib/directory.rb",
    "lib/errors.rb",
    "lib/kinesis_client.rb",
    "lib/kms_client.rb",
    "lib/nypl_avro.rb",
    "lib/platform_api_client.rb",
    "lib/deploy_helper.rb"
  ]
  s.license = "MIT"
end

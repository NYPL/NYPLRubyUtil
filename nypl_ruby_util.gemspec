Gem::Specification.new do |s|
  s.name = "nypl_ruby_util"
  s.version = "0.0.0"
  s.date = "2020-07-13"
  s.description = "A repository of common utilities for NYPL Ruby application"
  s.summary = "A repository of common utilities for NYPL Ruby application"
  s.author = ["Daniel Appel"]
  s.files = ["lib/nypl_ruby_util.rb",
    "lib/directory.rb",
    "lib/errors.rb",
    "lib/kinesis_client.rb",
    "lib/kms_client.rb",
    "lib/nypl_avro.rb",
    "lib/platform_api_client.rb"
  ]
  s.license = "MIT"
end

require 'nypl_log_formatter'
require 'nypl_sierra_api_client'
require_relative 'kms_client'
require_relative 'platform_api_client'
require_relative 'directory'
require_relative 'nypl_avro'
require_relative 'errors'
require_relative 'kinesis_client'

class NYPLRubyUtil
  class SierraApiClient < SierraApiClient
  end

  class NyplLogFormatter < NyplLogFormatter
  end

  class KmsClient < KmsClient
  end

  class NYPLAvro < NYPLAvro
  end

  class PlatformApiClient < PlatformApiClient
  end

  class KinesisClient < KinesisClient
  end
end

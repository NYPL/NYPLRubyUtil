require 'securerandom'
require 'aws-sdk-kinesis'
require_relative 'nypl_avro'
require_relative 'errors'
# Model representing the result message posted to Kinesis stream about everything that has gone on here -- good, bad, or otherwise.

class KinesisClient
  attr_reader :config, :avro

  def initialize(config)
    @config = config
    @avro = nil

    if config[:schema_string]
      @avro = NYPLAvro.by_name(config[:schema_string])
    end

  end

  def <<(json_message)
    p '<< ', config[:schema_string], avro
    if config[:schema_string]
      message = avro.encode(json_message)
    else
      message = json_message
    end

    client = Aws::Kinesis::Client.new
    partition_key = (config[:partition_key] ? json_message[config[:partition_key]] : SecureRandom.hex(20)).hash

    resp = client.put_record({
      stream_name: config[:stream_name],
      data: message,
      partition_key: partition_key
      })

      return_hash = {}

      if resp.successful?
        return_hash["code"] = "200"
        return_hash["message"] = json_message, resp
        $logger.info("Message sent to HoldRequestResult #{json_message}, #{resp}") if $logger
      else
        $logger.error("message" => "FAILED to send message to HoldRequestResult #{json_message}, #{resp}.") if $logger
        raise NYPLError.new json_message, resp
      end
      return_hash
  end
end

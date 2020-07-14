require 'securerandom'
require 'aws-sdk'
require_relative 'nypl_avro'
# Model representing the result message posted to Kinesis stream about everything that has gone on here -- good, bad, or otherwise.

class KinesisClient
  attr_reader :config

  def initialize(config)
    @config = config
  end

  def <<(json_message)
    if config[:schema_string]
      message = NYPLAvro.new(config[:schema_string]).encode(json_message)
    else
      message = json_message
    end
    client = Aws::Kinesis::Client.new

    resp = client.put_record({
      stream_name: config[:stream_name],
      data: message,
      partition_key: SecureRandom.hex(20)
      })

      return_hash = {}

      if resp.successful?
        return_hash["code"] = "200"
        return_hash["message"] = json_message, resp
        $logger.info("Message sent to HoldRequestResult #{json_message}, #{resp}") if $logger
      else
        return_hash["code"] = "500"
        return_hash["message"] = json_message, resp
        $logger.error("message" => "FAILED to send message to HoldRequestResult #{json_message}, #{resp}.") if $logger
      end
      return_hash
  end
end

require 'securerandom'
require 'aws-sdk-kinesis'
require_relative 'nypl_avro'
require_relative 'errors'
# Model representing the result message posted to Kinesis stream about everything that has gone on here -- good, bad, or otherwise.

class KinesisClient
  attr_reader :config, :avro

  def initialize(config, batch_size = 1, automatically_push = true)
    @config = config
    @stream_name = @config[:stream_name]
    @avro = nil
    @batch_size = batch_size
    @batch = []
    @automatically_push = automatically_push
    @client_options = config[:profile] ? { profile: config[:profile] } : {}
    @client = Aws::Kinesis::Client.new @client_options

    if config[:schema_string]
      @avro = NYPLAvro.by_name(config[:schema_string])
    end

    @shovel_method = batch_size > 1 ? :push_to_batch : :push_record

  end

  def convert_to_record(json_message)
    if config[:schema_string]
      message = avro.encode(json_message, false)
    else
      message = json_message
    end

    partition_key = (config[:partition_key] ? json_message[config[:partition_key]] : SecureRandom.hex(20)).hash.to_s
    {
      data: message,
      partition_key: partition_key
    }

  end

  def <<(json_message)
    send(@shovel_method, json_message)
  end

  def push_record(json_message)
    record = convert_to_record json_message
    record[:stream_name] = @stream_name

    @client.put_record record

    return_hash = {}

    if resp.successful?
      return_hash["code"] = "200"
      return_hash["message"] = json_message, resp
      $logger.info("Message sent to #{config[:stream_name]} #{json_message}, #{resp}") if $logger
    else
      $logger.error("message" => "FAILED to send message to HoldRequestResult #{json_message}, #{resp}.") if $logger
      raise NYPLError.new json_message, resp
    end
    return_hash
  end

  def push_to_batch(json_message)
    begin
      @batch << convert_to_record(json_message)
    rescue AvroError => e
      $logger.error("message" => "Avro encoding error #{e.message} for #{json_message}")
    end
    if @automatically_push && @batch.length >= @batch_size
      push_records
    end
  end

  def push_batch(batch)
    resp = @client.put_records({
      records: batch.to_a,
      stream_name: @stream_name
    })

    $logger.debug("Received #{resp} from #{@stream_name}")

    return_message = {
      failures: resp.failed_record_count,
      error_messages: resp.records.map {|record| record.error_message }.compact
    }

    $logger.info("Message sent to #{config[:stream_name]} #{return_message}") if $logger

    return {
      "code": "200",
      "message": return_message.to_json
    }
  end

  def push_records
    @batch.each_slice(@batch_size) {|slice| push_batch slice}
    @batch = []
  end
end

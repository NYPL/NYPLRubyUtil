require "securerandom"
require "aws-sdk-kinesis"
require_relative "nypl_avro"
require_relative "errors"
# Model representing the result message posted to Kinesis stream about everything that has gone on here -- good, bad, or otherwise.

class KinesisClient
  attr_reader :config, :avro, :failed_records

  def initialize(config)
    @config = config
    @stream_name = @config[:stream_name]
    @avro = nil
    @batch_size = @config[:batch_size] || 1
    @records = []
    @failed_records = []
    @automatically_push = !(@config[:automatically_push] == false)
    @client_options = config[:profile] ? { profile: config[:profile] } : {}
    @client = Aws::Kinesis::Client.new(@client_options)

    @avro = NYPLAvro.by_name(config[:schema_string]) if config[:schema_string]

    @shovel_method = @batch_size > 1 ? :push_to_records : :push_record
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

#This method is broken
#TO DO: figure out how to determine successful or failed record, successful? is not a method on the object
  def push_record(json_message)
    record = convert_to_record(json_message)
    record[:stream_name] = @stream_name

    @client.put_record(record)

    return_hash = {}

    if resp.successful?
      return_hash["code"] = "200"
      return_hash["message"] = json_message, resp
      $logger.info("Message sent to #{config[:stream_name]} #{json_message}, #{resp}") if $logger
    else
      $logger.error("message" => "FAILED to send message to #{@stream_name} #{json_message}, #{resp}.") if $logger
      raise(NYPLError.new(json_message, resp))
    end
    return_hash
  end

  def push_to_records(json_message)
    begin
      @records << convert_to_record(json_message)
    rescue AvroError => e
      $logger.error("message" => "Avro encoding error #{e.message} for #{json_message}")
    end
    push_records if @automatically_push && @records.length >= @batch_size
  end

  def push_batch(batch)
    resp = @client.put_records({
      records: batch.to_a,
      stream_name: @stream_name
    })
    filter_failures(resp, batch) if resp.failed_record_count > 0
  end

  def push_records
    if @records.length > 0 
      @records.each_slice(@batch_size) do |slice|
        push_batch(slice)
      end
      @records = []
    end
  end

  def filter_failures(resp, batch)
    resp.records.each_with_index do |record, i|
      @failed_records << batch[i] if record.responds_to?(:error_message)
    end
  end

  def retry_failed_records
    unless @failed_records.empty?
      @records = @failed_records
      @failed_records = []
      push_records
    end
  end

  def decode_failed_records
    @failed_records = @failed_records.map { |record| avro.decode(record) }
  end
end

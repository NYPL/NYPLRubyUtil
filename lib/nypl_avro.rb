require 'rubygems'
require 'avro'
require 'base64'

require_relative 'errors'
require_relative 'directory'

class NYPLAvro
  def initialize (schemaString)
    begin
      @schema = Avro::Schema.parse(schemaString)
    rescue Exception => e
      raise AvroError.new(e), "Failed to parse schema string: \"#{schemaString}\""
    end

    @reader = Avro::IO::DatumReader.new(@schema)
  end

  def decode(encoded_data_string, base64 = true)
    avro_string = base64 ? Base64.decode64(encoded_data_string) : encoded_data_string
    stringreader = StringIO.new(avro_string)
    bin_decoder = Avro::IO::BinaryDecoder.new(stringreader)
    begin
      read_value = @reader.read(bin_decoder)
    rescue Exception => e
      raise AvroError.new(e), "Error decoding data using #{@schema.name} schema"
    end

    read_value
  end

  def encode(decoded_data, base64 = true)
    bin_encoder = Avro::IO::DatumWriter.new(@schema)
    buffer = StringIO.new
    buffer.set_encoding('UTF-8')
    encoder = Avro::IO::BinaryEncoder.new(buffer)

    begin
      bin_encoder.write(decoded_data, encoder)
    rescue Avro::IO::AvroTypeError => e
      raise AvroError.new(e), "Error encoding data #{decoded_data} using #{@schema.name} schema due to #{e.message}"
    end

    buffer.rewind
    result = buffer.read
    base64 ? Base64.encode64(result) : result
  end

  def self.by_name (name)
    require 'net/http'
    require 'uri'

    uri = URI.parse("#{ENV["PLATFORM_API_BASE_URL"]}current-schemas/#{name}")
    begin
      response = Net::HTTP.get_response(uri)
    rescue Exception => e
      raise AvroError.new(e), "Failed to retrieve #{name} schema: #{e.message}"
    end

    begin
      response_hash = JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise AvroError.new(e), "Retrieved #{name} schema is malformed: #{response.body}"
    end

    raise AvroError.new, "Failed to retrieve #{name} schema: statusCode=#{response_hash["statusCode"]}" if response_hash["statusCode"] >= 400
    raise AvroError.new, "Retrieved #{name} schema is malformed" if response_hash["data"].nil? || response_hash["data"]["schema"].nil?

    self.new response_hash["data"]["schema"]
  end
end

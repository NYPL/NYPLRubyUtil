require 'spec_helper'
require 'json'
require_relative '../../lib/nypl_avro'

AvroClient = NYPLRubyUtil::NYPLAvro

mock_schema = JSON.dump({
    "name" => "TestRecord",
    "type" => "record",
    "fields" => [
        {
            "name" => "id",
            "type" => "int"
        }
    ]
})

describe AvroClient do
  describe :config do
    it "should initialize config with schema" do
        test_avro = AvroClient.new(mock_schema)
        expect(test_avro.instance_variable_get(:@reader).class).to eq(Avro::IO::DatumReader)
    end
  end

  describe :encode do
    it "should return utf-8 encoded string with Base64 set to false" do
      test_avro = AvroClient.new(mock_schema)
      encoded_rec = test_avro.encode({ 'id' => 1 }, base64=false)
      expect(encoded_rec.class).to eq(String)
      expect(encoded_rec.encoding).to eq(Encoding::UTF_8)

      # Decode to verify that it works
      decoded_rec = test_avro.decode(encoded_rec, base64=false)
      expect(decoded_rec['id']).to eq(1)
    end

    it "should return bas64 string with default Base64=true" do
      test_avro = AvroClient.new(mock_schema)
      encoded_rec = test_avro.encode({ 'id' => 1 })
      expect(encoded_rec.class).to eq(String)
      # Intended because we can trust the set of ASCII characters in a bas64 string
      expect(encoded_rec.encoding).to eq(Encoding::US_ASCII)

      # Decode to verify that it works
      decoded_rec = test_avro.decode(encoded_rec)
      expect(decoded_rec['id']).to eq(1)
    end

    it "should raise an AvroError if the record being encoded does not match the schema" do
      test_avro = AvroClient.new(mock_schema)
      expect { test_avro.send(:encode, { 'other' => 'thing' })}.to raise_error(AvroError)
    end
  end
end
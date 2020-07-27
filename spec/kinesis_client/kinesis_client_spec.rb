require 'spec_helper'
require 'aws-sdk-kinesis'
require_relative '../../lib/nypl_avro'

KinesisClient = NYPLRubyUtil::KinesisClient

class MockAvro
  def encode(*args)
  end
end

class MockClient
  def put_record(*args)
  end
end

class MockSuccessResponse
  def successful?
    true
  end
end

class MockLogger
  def info(*args)
  end

  def error(*args)
  end
end

describe KinesisClient do

  describe :config do

    mock_avro = nil

    before do
      mock_avro = MockAvro.new
      mock_client = MockClient.new
      $logger = MockLogger.new
      allow(NYPLAvro).to receive(:by_name).and_return(mock_avro)
      allow(Aws::Kinesis::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:put_record).and_return(MockSuccessResponse.new)
      allow(mock_avro).to receive(:encode).and_return("encoded")
    end

    it "should initialize config" do
      kinesis_client = KinesisClient.new({ foo: 'bar' })
      expect(kinesis_client.instance_variable_get(:@config)).to eq({ foo: "bar" })
    end

    it "should initialize avro based on schema string" do
      kinesis_client = KinesisClient.new({ schema_string: 'foobar' })
      expect(kinesis_client.instance_variable_get(:@avro)).to eq(mock_avro)
    end

    it "should set avro to nil if no schema_string provided" do
      kinesis_client = KinesisClient.new({})
      expect(kinesis_client.instance_variable_get(:@avro)).to eq(nil)
    end

  end

  describe "writing a message" do
    mock_avro = MockAvro.new
    mock_client = MockClient.new

    before do
      allow(NYPLAvro).to receive(:by_name).and_return(mock_avro)
      allow(mock_avro).to receive(:encode).and_return('encoded')
      allow(Aws::Kinesis::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:put_record).and_return(MockSuccessResponse.new)
    end

    # it "should pass the encoded message if given an avro" do
    #   json_message = { fake: 'fake' }
    #   kinesis_client = KinesisClient.new({ schema_string: 'foo'})
    #   expect(kinesis_client).to receive(:<<)
    #   expect(mock_client).to receive(:put_record).with(hash_including({ data: 'encoded' }))
    #   expect(mock_avro).to receive(:encode).with(json_message)
    #   p 'avro ', kinesis_client.avro, kinesis_client.config[:schema_string]
    #   kinesis_client << json_message
    # end

    # it "should pass the unencoded message if not given avro" do
    # end
    #
    # it "should pass the message to the correct stream" do
    # end
    #
    # it "should use the configured partition key" do
    # end
    #
    # it "should default to a random partition key" do
    # end
    #
    # it "should return te message with status 200 if successful" do
    # end
    #
    # it "should log if successful" do
    # end
    #
    # it "should raise an NYPL error if unsuccessful" do
    # end
    #
    # it "should log an error if unsuccessful" do
    # end
  end
end

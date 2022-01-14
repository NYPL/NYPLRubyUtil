require 'spec_helper'
require_relative '../../lib/nypl_avro'
require_relative '../../lib/kinesis_client'

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
  before(:each) do
    @mock_client = double()
    allow(Aws::Kinesis::Client).to receive(:new).and_return @mock_client
      @mock_avro = double()
      allow(NYPLAvro).to receive(:by_name).and_return(@mock_avro)
      allow(@mock_avro).to receive(:encode) {|x| "encoded #{x}"}
      allow(@mock_avro).to receive(:decode) {|x| x[:data].delete("encoded ")}
      @kinesis_client = KinesisClient.new({
          schema_string: 'really_fake_schema',
          stream_name: 'fake-stream',
          batch_size: 3
      })
      @mock_random = double()
      allow(SecureRandom).to receive(:hex).and_return(@mock_random)
      allow(@mock_random).to receive(:hash).and_return("hashed")
      $logger = double()
      allow($logger).to receive(:debug)
      allow($logger).to receive(:info)
  end

  describe :config do

    mock_avro = nil

    before do
      mock_avro = MockAvro.new
      mock_client = MockClient.new
      $logger = double()
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

  describe 'writing messages in batches' do

    before(:each) do
      # $logger = double()
      # allow($logger).to receive(:debug)
      # allow($logger).to receive(:info)
      # @mock_client = double()
      # allow(Aws::Kinesis::Client).to receive(:new).and_return @mock_client
      # @mock_avro = double()
      # allow(NYPLAvro).to receive(:by_name).and_return(@mock_avro)
      # allow(@mock_avro).to receive(:encode) {|x| "encoded #{x}"}
      # @kinesis_client = KinesisClient.new({
      #     schema_string: 'really_fake_schema',
      #     stream_name: 'fake-stream',
      #     batch_size: 3
      # })
      # @mock_random = double()
      # allow(SecureRandom).to receive(:hex).and_return(@mock_random)
      # allow(@mock_random).to receive(:hash).and_return("hashed")
      @mock_resp = double()
      allow(@mock_resp).to receive(:failed_record_count).and_return(0)
      allow(@mock_resp).to receive(:records).and_return([])
      allow(@mock_client).to receive(:put_records).with({
        records: [
          {
            data: "encoded 1",
            partition_key: "hashed"
          },
          {
            data: "encoded 2",
            partition_key: "hashed"
          },
          {
            data: "encoded 3",
            partition_key: "hashed"
          },
        ],
        stream_name: 'fake-stream'
      }).and_return({
        failed_record_count: 0,
        records: []
      }).and_return(@mock_resp)
      allow(@mock_client).to receive(:put_records).with({
        records: [
          {
            data: "encoded 4",
            partition_key: "hashed"
          },
          {
            data: "encoded 5",
            partition_key: "hashed"
          }
        ],
        stream_name: 'fake-stream'
      }).and_return(@mock_resp)
    end

    it 'should push configured number of records to Kinesis' do
      expect(@mock_client).to receive(:put_records).with({
        records: [
          {
            data: "encoded 1",
            partition_key: "hashed"
          },
          {
            data: "encoded 2",
            partition_key: "hashed"
          },
          {
            data: "encoded 3",
            partition_key: "hashed"
          },
        ],
        stream_name: 'fake-stream'
      })
      @kinesis_client << '1'
      @kinesis_client << '2'
      @kinesis_client << '3'
    end

    it 'should push remaining records to Kinesis' do
      allow(@mock_client).to receive(:put_records).with({
        records: [
          {
            data: "encoded 1",
            partition_key: "hashed"
          },
          {
            data: "encoded 2",
            partition_key: "hashed"
          },
        ],
        stream_name: 'fake-stream'
      }).and_return({
        failed_record_count: 0,
        records: []
      }).and_return(@mock_resp)
      expect(@mock_client).to receive(:put_records).with({
        records: [
          {
            data: "encoded 1",
            partition_key: "hashed"
          },
          {
            data: "encoded 2",
            partition_key: "hashed"
          },
        ],
        stream_name: 'fake-stream'
      })
      @kinesis_client << '1'
      @kinesis_client << '2'
      @kinesis_client.push_records
    end

    it 'should not send an empty array to push_batch' do
      expect(@mock_client).not_to receive(:put_records)
      @kinesis_client.push_records
    end

    it 'push_records should clear remaining records' do
      expect(@mock_client).to receive(:put_records).with({
        records: [
          {
            data: "encoded 4",
            partition_key: "hashed"
          },
          {
            data: "encoded 5",
            partition_key: "hashed"
          }
        ],
        stream_name: 'fake-stream'
      })
      @kinesis_client << '1'
      @kinesis_client << '2'
      @kinesis_client << '3'
      @kinesis_client << '4'
      @kinesis_client << '5'
      @kinesis_client.push_records
    end

    it "should log records that failed to enter the kinesis stream" do
      
    end 
  end

  describe "#filter_failures", only:true do 
  before(:each) do
    @mock_failed_response = double
    @mock_failed_record = double
    #flesh out mock_success_record
    @mock_success_record = double
    allow(@mock_failed_record).to receive(:error_message).and_return("error")
    allow(@mock_failed_response).to receive(:failed_record_count).and_return(1)
    allow(@mock_failed_response).to receive(:records)
      .and_return([@mock_success_record, @mock_failed_record])

  end
  it "should return records that failed to enter the kinesis stream" do
      @kinesis_client << '1'
      @kinesis_client << '2'

    expect(@kinesis_client.filter_failures(@mock_failed_response)).to eql([{record_data:"2",error_message:"error"}])
  end 

  it "should return an array that can be logged in #push_batch" do
  allow(@mock_client).to receive(:put_records).with({
        records: [
          {
            data: "encoded 4",
            partition_key: "hashed"
          },
          {
            data: "encoded 5",
            partition_key: "hashed"
          }
        ],
        stream_name: 'fake-stream'
      }).and_return(@mock_failed_response)

    message = {:failures=>1,:failures_data=>{:record_data=>'5',error_message:"error"}}.to_json
    expect(@kinesis_client).to receive(:push_batch).with([{:data=>"encoded 4", :partition_key=>"hashed"},{:data=>"encoded 5", :partition_key=>"hashed"}]).and_return({
      "code": "200",
      "message": message
    })
    @kinesis_client << '4'
    @kinesis_client << '5'
    @kinesis_client.push_records
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

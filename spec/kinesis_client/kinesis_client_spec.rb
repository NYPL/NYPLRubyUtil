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
      @mock_resp = double()
      allow(@mock_resp).to receive(:failed_record_count).and_return(0)
      allow(@mock_resp).to receive(:records).and_return([])
      @mock_failed_response = double
      @mock_failed_record = double
      @mock_success_record = double
      allow(@mock_failed_record).to receive(:error_message).and_return("error")
      allow(@mock_failed_record).to receive(:responds_to?).with(:error_message).and_return(true)
      allow(@mock_success_record).to receive(:responds_to?).with(:error_message).and_return(false)
      allow(@mock_failed_response).to receive(:failed_record_count).and_return(1)
      allow(@mock_failed_response).to receive(:records)
        .and_return([@mock_success_record, @mock_failed_record])
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
  end

  describe "#filter_failures" do
    before(:each) do
    end

    it "should push encoded records that did not enter the kinesis stream to @failed_records" do
        @kinesis_client << '1'
        @kinesis_client << '2'
        @kinesis_client.filter_failures(@mock_failed_response,[{:data=>"encoded 1", :partition_key=>"hashed"},{:data=>"encoded 2", :partition_key=>"hashed"}])

      expect(@kinesis_client.failed_records.flatten).to eql([{:data=>"encoded 2", :partition_key=>"hashed"}])
    end 

    it "should create a nested array @failed_records when there are failures across batches" do
      kinesis_client = KinesisClient.new({
        schema_string: 'really_fake_schema',
        stream_name: 'fake-stream',
        batch_size: 3,
        automatically_push: false
      })
      another_mock_failed_response = double
      allow(another_mock_failed_response).to receive(:records)
        .and_return([@mock_success_record, @mock_success_record, @mock_failed_record])
      allow(another_mock_failed_response).to receive(:failed_record_count)
        .and_return(1)

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
        }).and_return(another_mock_failed_response)
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

      kinesis_client << '1'
      kinesis_client << '2'
      kinesis_client << '3'
      kinesis_client << '4'
      kinesis_client << '5'
      kinesis_client.push_records
      expect(kinesis_client.failed_records).to eql([{:data=>"encoded 3", :partition_key=>"hashed"},{:data=>"encoded 5", :partition_key=>"hashed"}])
    end
  end

  describe "#retry_failed_records" do
    it('does not call push_records with an empty @failed_records') do
      expect(@kinesis_client).to_not receive(:push_records)
      @kinesis_client.retry_failed_records
    end

    it('clears @failed_records') do
      # problem here is push records is called twice w different args
      allow(@mock_client).to receive(:put_records).and_return(@mock_failed_response)
      expect(@kinesis_client.failed_records).to be_empty
      @kinesis_client << "4"
      @kinesis_client << "5"
      @kinesis_client.push_records
      @kinesis_client.retry_failed_records
    end

    it('calls push_records on the records in @failed_records') do
      allow(@mock_client).to receive(:put_records).with({
        records: [
          {
            data: "encoded 4",
            partition_key: "hashed"
          },
          {
            data: "encoded 5",
            partition_key: "hashed"
          },
        ],
        stream_name: 'fake-stream'
      }).and_return(@mock_failed_response)
      @kinesis_client << '4'
      @kinesis_client << '5'
      @kinesis_client.push_records
      expect(@kinesis_client).to receive(:push_records)
      @kinesis_client.retry_failed_records
    end
  end

  describe "#decode_failed_records" do
    it('decodes the records in @failed_records') do
      allow(@mock_client).to receive(:put_records).and_return(@mock_failed_response)
      @kinesis_client << '4'
      @kinesis_client << '5'
      @kinesis_client.push_records
      @kinesis_client.decode_failed_records
      expect(@kinesis_client.failed_records).to eql(['5'])
    end
  end


  describe "#push_record" do

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

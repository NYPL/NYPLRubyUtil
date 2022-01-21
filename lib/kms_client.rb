require "aws-sdk-kms"
require "base64"

class KmsClient
  @@kms = nil

  def initialize(options = {})
    options ||= {}
    @kms = self.class.aws_kms_client(options)
  end

  def decrypt(cipher)
    # Assume value is base64 encoded:
    decoded = Base64.decode64(cipher)
    decrypted = @kms.decrypt(ciphertext_blob: decoded)
    decrypted[:plaintext]
  end

  def self.aws_kms_client(options)
    params = {
      region: "us-east-1",
      stub_responses: ENV["APP_ENV"] == "test"
    }.merge(options)
    @@kms = Aws::KMS::Client.new(params) if @@kms.nil?
    @@kms
  end
end

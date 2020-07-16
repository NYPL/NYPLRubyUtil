class NYPLError < StandardError
  attr_reader :object

  def initialize(object='')
    @object = object
  end
end

class AvroError < NYPLError
end

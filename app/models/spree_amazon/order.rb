class SpreeAmazon::Order
  class << self
    def find(order_reference)
      new(reference_id: order_reference).fetch
    end
  end

  attr_accessor :state, :total, :email, :address, :reference_id, :currency

  def initialize(attributes)
    self.attributes = attributes
  end

  def fetch
    response = mws.fetch_order_data
    self.attributes = attributes_from_response(response)
  end

  def confirm
    mws.confirm
  end

  def save_total
    mws.set_order_data(total, currency)
  end

  private

  def attributes=(attributes)
    attributes.each_pair do |key, value|
      send("#{key}=", value)
    end
  end

  def mws
    @mws ||= AmazonMws.new(reference_id, test_mode)
  end

  def test_mode
    Spree::Gateway::Amazon.first.preferred_test_mode
  end

  def attributes_from_response(response)
    {
      state: response.state,
      total: response.total,
      email: response.email,
      address: SpreeAmazon::Address.from_response(response)
    }
  end
end

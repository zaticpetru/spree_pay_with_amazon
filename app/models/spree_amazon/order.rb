class SpreeAmazon::Order
  class << self
    def find(order_reference, gateway:)
      new(reference_id: order_reference, gateway: gateway).fetch
    end
  end

  attr_accessor :state, :total, :email, :address, :reference_id, :currency,
                :gateway

  def initialize(attributes)
    if !attributes.key?(:gateway)
      raise ArgumentError, "SpreeAmazon::Order requires a gateway parameter"
    end
    self.attributes = attributes
  end

  def fetch
    response = mws.fetch_order_data
    self.attributes = attributes_from_response(response)
    self
  end

  def confirm
    mws.confirm_order
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
    @mws ||= AmazonMws.new(reference_id, gateway: gateway)
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

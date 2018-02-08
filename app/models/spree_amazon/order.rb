class SpreeAmazon::Order
  class CloseFailure < StandardError; end

  attr_accessor :state, :total, :email, :address, :reference_id, :currency,
                :gateway, :address_consent_token, :billing_address

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

  def close_order_reference!
    response = mws.close_order_reference
    parsed_response = Hash.from_xml(response.body) rescue nil

    if response.success
      success = true
      message = 'Success'
    else
      success = false
      message = if parsed_response && parsed_response['ErrorResponse']
        error = parsed_response.fetch('ErrorResponse').fetch('Error')
        "#{response.code} #{error.fetch('Code')}: #{error.fetch('Message')}"
      else
        "#{response.code} #{response.body}"
      end

    end

     ActiveMerchant::Billing::Response.new(
      success,
      message,
      {
        'response' => response,
        'parsed_response' => parsed_response,
      },
    )
  end

  # @param total [String] The amount to set on the order
  # @param amazon_options [Hash] These options are forwarded to the underlying
  #   call to PayWithAmazon::Client#set_order_reference_details
  def set_order_reference_details(total, amazon_options={})
    SpreeAmazon::Response::SetOrderReferenceDetails.new mws.set_order_reference_details(total, amazon_options)
  end

  private

  def attributes=(attributes)
    attributes.each_pair do |key, value|
      send("#{key}=", value)
    end
  end

  def mws
    @mws ||= AmazonMws.new(
      reference_id,
      gateway: gateway,
      address_consent_token: address_consent_token,
    )
  end

  def attributes_from_response(response)
    {
      state: response.state,
      total: response.total,
      email: response.email,
      address: response.destination['PhysicalDestination'].blank? ? nil : SpreeAmazon::Address.from_attributes(response.destination['PhysicalDestination']),
      billing_address: response.billing_address['PhysicalAddress'].blank? ? nil : SpreeAmazon::Address.from_attributes(response.billing_address['PhysicalAddress'])
    }
  end
end

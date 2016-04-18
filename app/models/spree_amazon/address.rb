class SpreeAmazon::Address
  class << self
    def find(order_reference)
      response = mws(order_reference).fetch_order_data
      from_response(response)
    end

    def from_response(response)
      if response.destination["PhysicalDestination"].blank?
        return nil
      end
      new attributes_from_response(response.destination["PhysicalDestination"])
    end

    private

    def mws(order_reference)
      AmazonMws.new(order_reference, test_mode)
    end

    def test_mode
      Spree::Gateway::Amazon.first.preferred_test_mode
    end

    def attributes_from_response(response)
      {
        address1: response["AddressLine1"],
        name: response["Name"],
        city: response["City"],
        zipcode: response["PostalCode"],
        state_name: response["StateOrRegion"],
        country_code: response["CountryCode"],
        phone: response["Phone"]
      }
    end
  end

  attr_accessor :name, :city, :zipcode, :state_name, :country_code,
                :address1, :phone

  def initialize(attributes)
    attributes.each_pair do |key, value|
      send("#{key}=", value)
    end
  end

  def first_name
    unless name.blank?
      name.split(" ").first
    end
  end

  def last_name
    unless name.blank?
      names = name.split(" ")
      names.shift
      names.join(" ")
    end
  end

  def country
    @country ||= Spree::Contry.find_by(iso: country_code)
  end
end

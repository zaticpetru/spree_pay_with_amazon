class AddCurrencyToAmazonGateway < ActiveRecord::Migration
  def change
    amazon_gateways = Spree::Gateway::Amazon.where(active: true).all

    return if amazon_gateways.empty?

    if amazon_gateways.size > 1
      raise "Unable to migrate credentials. More than one active Amazon Gateway found. Please adjust this migration manually."
    end

    gateway = amazon_gateways.first

    reversible do |direction|
      direction.up do
        gateway.update!(preferred_currency: Spree::Config.currency)
      end

      direction.down do
        gateway.update!(preferred_currency: nil)
      end
    end
  end
end

class CopyAmazonCredentialsToGateway < ActiveRecord::Migration
  def change
    amazon_gateways = Spree::Gateway::Amazon.where(active: true).all

    return if amazon_gateways.empty?

    if amazon_gateways.size > 1
      raise "Unable to migrate credentials. More than one active Amazon Gateway found. Please adjust this migration manually."
    end

    gateway = amazon_gateways.first

    reversible do |direction|
      direction.up do
        if aws_access_key_id = Spree::Preference.find_by(key: 'spree_amazon/configuration/aws_access_key_id').try!(:value)
          gateway.preferred_aws_access_key_id = aws_access_key_id
        end
        if aws_secret_access_key = Spree::Preference.find_by(key: 'spree_amazon/configuration/aws_secret_access_key').try!(:value)
          gateway.preferred_aws_secret_access_key = aws_secret_access_key
        end
        if client_id = Spree::Preference.find_by(key: 'spree_amazon/configuration/client_id').try!(:value)
          gateway.preferred_client_id = client_id
        end
        if merchant_id = Spree::Preference.find_by(key: 'spree_amazon/configuration/merchant_id').try!(:value)
          gateway.preferred_merchant_id = merchant_id
        end
        gateway.save!
      end

      direction.down do
        gateway.update!(
          preferred_aws_access_key_id:  nil,
          preferred_aws_secret_access_key:  nil,
          preferred_client_id:  nil,
          preferred_merchant_id:  nil,
        )
      end
    end
  end
end

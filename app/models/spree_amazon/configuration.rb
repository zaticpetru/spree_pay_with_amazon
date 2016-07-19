class SpreeAmazon::Configuration < Spree::Preferences::Configuration
  def client_id
    Spree::Deprecation.warn("SpreeAmazon::Config.client_id is deprecated. Use Spree::Gateway::Amazon#preferred_client_id instead.", caller)
    # Default to the old behavior of using the first Gateway
    Spree::Gateway::Amazon.first.try!(:preferred_client_id)
  end
  def merchant_id
    Spree::Deprecation.warn("SpreeAmazon::Config.merchant_id is deprecated. Use Spree::Gateway::Amazon#preferred_merchant_id instead.", caller)
    # Default to the old behavior of using the first Gateway
    Spree::Gateway::Amazon.first.try!(:preferred_merchant_id)
  end
  def aws_access_key_id
    Spree::Deprecation.warn("SpreeAmazon::Config.aws_access_key_id is deprecated. Use Spree::Gateway::Amazon#preferred_aws_access_key_id instead.", caller)
    # Default to the old behavior of using the first Gateway
    Spree::Gateway::Amazon.first.try!(:preferred_aws_access_key_id)
  end
  def aws_secret_access_key
    Spree::Deprecation.warn("SpreeAmazon::Config.aws_secret_access_key is deprecated. Use Spree::Gateway::Amazon#preferred_aws_secret_access_key instead.", caller)
    # Default to the old behavior of using the first Gateway
    Spree::Gateway::Amazon.first.try!(:preferred_aws_secret_access_key)
  end
end

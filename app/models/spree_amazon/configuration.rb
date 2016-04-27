class SpreeAmazon::Configuration < Spree::Preferences::Configuration
  preference :client_id, :string
  preference :merchant_id, :string
  preference :aws_access_key_id, :string
  preference :aws_secret_access_key, :string

  def use_static_preferences!
    raise "SpreeAmazon::Configuration cannot use static preferences"
  end
end

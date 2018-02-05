class Spree::AmazonSessionController < Spree::StoreController
  skip_before_action :verify_authenticity_token

  def logout
    @amazon_gateway = Spree::Gateway::Amazon.for_currency(Spree::Config.currency)
    @redirect_to = params[:redirect_to] || root_path
  end
end

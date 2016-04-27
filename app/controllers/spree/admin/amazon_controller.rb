##
# Amazon Payments - Login and Pay for Spree Commerce
#
# @category    Amazon
# @package     Amazon_Payments
# @copyright   Copyright (c) 2014 Amazon.com
# @license     http://opensource.org/licenses/Apache-2.0  Apache License, Version 2.0
#
##
class Spree::Admin::AmazonController < Spree::Admin::BaseController
  def edit
  end

  def update
    params.each do |key, value|
      next unless SpreeAmazon::Config.has_preference? key
      SpreeAmazon::Config[key] = value
    end

    flash[:success] = Spree.t(:successfully_updated, :resource => Spree.t(:amazon_settings))
    redirect_to edit_admin_amazon_path
  end
end

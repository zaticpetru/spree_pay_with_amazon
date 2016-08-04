##
# Amazon Payments - Login and Pay for Spree Commerce
#
# @category    Amazon
# @package     Amazon_Payments
# @copyright   Copyright (c) 2014 Amazon.com
# @license     http://opensource.org/licenses/Apache-2.0  Apache License, Version 2.0
#
##
FactoryGirl.define do
  factory :amazon_transaction, class: Spree::AmazonTransaction do
    authorization_id "AUTHORIZATION_ID"
    capture_id "CAPTURE_ID"
    order_reference "ORDER_REFERENCE"
  end

  factory :amazon_gateway, parent: :payment_method, class: Spree::Gateway::Amazon do
    sequence(:name) { |n| "Amazon Gateway #{n}" }
    preferred_test_mode true
    preferred_currency 'USD'
    preferred_client_id ''
    preferred_merchant_id ''
    preferred_aws_access_key_id ''
    preferred_aws_secret_access_key ''
  end
end

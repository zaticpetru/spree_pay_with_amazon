##
# Amazon Payments - Login and Pay for Spree Commerce
#
# @category    Amazon
# @package     Amazon_Payments
# @copyright   Copyright (c) 2014 Amazon.com
# @license     http://opensource.org/licenses/Apache-2.0  Apache License, Version 2.0
#
##
Spree::Order.class_eval do
  has_many :amazon_transactions

  def amazon_transaction
    amazon_transactions.last
  end

  def amazon_order_reference_id
    amazon_transaction.try(:order_reference)
  end

  module ConfirmationRequiredWithAmazon
    def confirmation_required?
      super || payments.valid.map(&:payment_method).compact.any? { |pm| pm.is_a? Spree::Gateway::Amazon }
    end
  end
  prepend ConfirmationRequiredWithAmazon

  module CancelDefaultCreditCardWhenValidAmazon
    def assign_default_credit_card
      return if payments.valid.amazon.count > 0
      super
    end
  end
  prepend CancelDefaultCreditCardWhenValidAmazon
end

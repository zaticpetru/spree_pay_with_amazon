##
# Amazon Payments - Login and Pay for Spree Commerce
#
# @category    Amazon
# @package     Amazon_Payments
# @copyright   Copyright (c) 2014 Amazon.com
# @license     http://opensource.org/licenses/Apache-2.0  Apache License, Version 2.0
#
##
module Spree
  class Gateway::Amazon < Gateway
    REGIONS = %w(us uk de jp).freeze

    preference :currency, :string, default: -> { Spree::Config.currency }
    preference :client_id, :string
    preference :merchant_id, :string
    preference :aws_access_key_id, :string
    preference :aws_secret_access_key, :string
    preference :region, :string, default: 'us'

    has_one :provider

    validates :preferred_region, inclusion: { in: REGIONS }

    def self.for_currency(currency)
      where(active: true).detect { |gateway| gateway.preferred_currency == currency }
    end

    def api_url
      sandbox = preferred_test_mode ? '_Sandbox' : ''
      {
        'us' => "https://mws.amazonservices.com/OffAmazonPayments#{sandbox}/2013-01-01",
        'uk' => "https://mws-eu.amazonservices.com/OffAmazonPayments#{sandbox}/2013-01-01",
        'de' => "https://mws-eu.amazonservices.com/OffAmazonPayments#{sandbox}/2013-01-01",
        'jp' => "https://mws.amazonservices.jp/OffAmazonPayments#{sandbox}/2013-01-01",
      }.fetch(preferred_region)
    end

    def widgets_url
      sandbox = preferred_test_mode ? '/sandbox' : ''
      {
        'us' => "https://static-na.payments-amazon.com/OffAmazonPayments/us#{sandbox}/js/Widgets.js",
        'uk' => "https://static-eu.payments-amazon.com/OffAmazonPayments/uk#{sandbox}/lpa/js/Widgets.js",
        'de' => "https://static-eu.payments-amazon.com/OffAmazonPayments/de#{sandbox}/lpa/js/Widgets.js",
        'jp' => "https://origin-na.ssl-images-amazon.com/images/G/09/EP/offAmazonPayments#{sandbox}/prod/lpa/js/Widgets.js",
      }.fetch(preferred_region)
    end

    def supports?(source)
      true
    end

    def method_type
      "amazon"
    end

    def provider_class
      AmazonTransaction
    end

    def payment_source_class
      AmazonTransaction
    end

    def source_required?
      true
    end

    def authorize(amount, amazon_checkout, gateway_options={})
      if amount < 0
        return ActiveMerchant::Billing::Response.new(true, "Success", {})
      end
      order = Spree::Order.find_by(:number => gateway_options[:order_id].split("-")[0])
      load_amazon_mws(order.amazon_order_reference_id)
      response = @mws.authorize(gateway_options[:order_id], amount / 100.0, order.currency)
      if response["ErrorResponse"]
        return ActiveMerchant::Billing::Response.new(false, response["ErrorResponse"]["Error"]["Message"], response)
      end
      t = order.amazon_transaction
      t.authorization_id = response["AuthorizeResponse"]["AuthorizeResult"]["AuthorizationDetails"]["AmazonAuthorizationId"]
      t.save
      return ActiveMerchant::Billing::Response.new(response["AuthorizeResponse"]["AuthorizeResult"]["AuthorizationDetails"]["AuthorizationStatus"]["State"] == "Open", "Success", response)
    end

    def capture(amount, amazon_checkout, gateway_options={})
      if amount < 0
        return credit(amount.abs, nil, nil, gateway_options)
      end
      order = Spree::Order.find_by(:number => gateway_options[:order_id].split("-")[0])
      load_amazon_mws(order.amazon_order_reference_id)

      authorization_id = order.amazon_transaction.authorization_id
      response = @mws.capture(authorization_id, "C#{Time.now.to_i}", amount / 100.00, order.currency)
      t = order.amazon_transaction
      t.capture_id = response.fetch("CaptureResponse", {}).fetch("CaptureResult", {}).fetch("CaptureDetails", {}).fetch("AmazonCaptureId", nil)
      t.save!
      return ActiveMerchant::Billing::Response.new(response.fetch("CaptureResponse", {}).fetch("CaptureResult", {}).fetch("CaptureDetails", {}).fetch("CaptureStatus", {})["State"] == "Completed", "OK", response)
    end

    def purchase(amount, amazon_checkout, gateway_options={})
      authorize(amount, amazon_checkout, gateway_options)
      capture(amount, amazon_checkout, gateway_options)
    end

    def credit(amount, _response_code, gateway_options = {})
      payment = gateway_options[:originator].payment
      amazon_transaction = payment.source

      load_amazon_mws(amazon_transaction.order_reference)
      response = @mws.refund(
        amazon_transaction.capture_id,
        payment.number,
        amount / 100.00,
        payment.currency
      )
      return ActiveMerchant::Billing::Response.new(true, "Success", response)
    end

    def void(response_code, gateway_options)
      order = Spree::Order.find_by(:number => gateway_options[:order_id].split("-")[0])
      load_amazon_mws(order.amazon_order_reference_id)
      capture_id = order.amazon_transaction.capture_id

      if capture_id.nil?
        response = @mws.cancel(order.amazon_transaction.order_reference)
      else
        response = @mws.refund(capture_id, gateway_options[:order_id], order.total, order.currency)
      end

      return ActiveMerchant::Billing::Response.new(true, "Success", response)
    end

    private

    def load_amazon_mws(reference)
      @mws ||= AmazonMws.new(reference, gateway: self)
    end
  end
end

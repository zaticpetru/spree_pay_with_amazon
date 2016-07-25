require 'spec_helper'

describe Spree::Gateway::Amazon do
  let(:payment_method) { Spree::Gateway::Amazon.create!(name: 'Amazon', preferred_test_mode: true) }
  let(:order) { create(:order_with_line_items, state: 'delivery') }
  let(:payment_source) { Spree::AmazonTransaction.create!(order_id: order.id, order_reference: 'REFERENCE') }
  let!(:payment) do
    create(:payment,
           order: order,
           payment_method: payment_method,
           source: payment_source,
           amount: order.total)
  end
  let(:mws) { stub_mws }
  
  describe "#credit" do
    it "calls refund on mws with the correct parameters" do
      gateway = create_gateway
      amazon_transaction = create(:amazon_transaction, capture_id: "CAPTURE_ID")
      payment = create(:payment, source: amazon_transaction, amount: 30.0, payment_method: gateway)
      refund = create(:refund, payment: payment, amount: 30.0)
      allow(mws).to receive(:refund).and_return({})

      gateway.credit(3000, nil, { originator: refund })

      expect(mws).to have_received(:refund).with("CAPTURE_ID", payment.number, 30.0, "USD")
    end

    let!(:refund) { create(:refund, payment: payment, amount: payment.amount) }
      it 'succeeds' do
      response = build_mws_refund_response(state: 'Pending', total: order.total)
      expect(mws).to receive(:refund).and_return(response)

      auth = payment_method.credit(order.total, payment_source, { originator: refund })
      expect(auth).to be_success
    end
  end

  describe '#void' do
    describe 'payment has not yet been captured' do
      it 'cancel succeeds' do
        response = build_mws_void_response
        expect(payment_method.send(:load_amazon_mws, 'REFERENCE')).to receive(:cancel).and_return(response)

        auth = payment_method.void('', {order_id: payment.send(:gateway_order_id)})
        expect(auth).to be_success
      end
    end

    describe 'payment has been previously captured' do
      let!(:refund) { create(:refund, payment: payment, amount: payment.amount) }

      it 'refund succeeds' do
        payment.order.amazon_transaction.update_attributes(capture_id: 'P01-1234567-1234567-0000002')
        response = build_mws_refund_response(state: 'Pending', total: order.total)
        expect(mws).to receive(:refund).and_return(response)

        auth = payment_method.void('', {order_id: payment.send(:gateway_order_id)})
        expect(auth).to be_success
      end
    end
  end

  describe '#authorize' do
    let(:payment_method) { Spree::Gateway::Amazon.create!(name: 'Amazon', preferred_test_mode: true) }
    let(:order) { create(:order_with_line_items, state: 'delivery') }
    let(:payment_source) { Spree::AmazonTransaction.create!(order_id: order.id, order_reference: 'REFERENCE') }
    let!(:payment) do
      create(:payment,
             order: order,
             payment_method: payment_method,
             source: payment_source,
             amount: order.total)
    end

    it "succeeds" do
      response = build_mws_auth_response(state: 'Open', total: order.total)
      expect(mws).to receive(:authorize).and_return(response)

      auth = payment_method.authorize(order.total, payment_source, {order_id: payment.send(:gateway_order_id)})
      expect(auth).to be_success
    end
  end

  describe '#capture' do
    let(:payment_method) { Spree::Gateway::Amazon.create!(name: 'Amazon', preferred_test_mode: true) }
    let(:order) { create(:order_with_line_items, state: 'delivery') }
    let(:payment_source) { Spree::AmazonTransaction.create!(order_id: order.id, order_reference: 'REFERENCE') }
    let!(:payment) do
      create(:payment,
             order: order,
             payment_method: payment_method,
             source: payment_source,
             amount: order.total)
    end

    it 'succeeds' do
      response = build_mws_capture_response(state: 'Completed', total: order.total)
      expect(mws).to receive(:capture).and_return(response)

      auth = payment_method.capture(order.total, payment_source, {order_id: payment.send(:gateway_order_id)})
      expect(auth).to be_success
    end
  end

  describe '.for_currency' do
    context 'when the currency exists and is active' do
      let!(:gbp_inactive_gateway) { create(:amazon_gateway, active: false, preferred_currency: 'GBP') }
      let!(:gbp_active_gateway) { create(:amazon_gateway, preferred_currency: 'GBP') }

      it 'finds the active gateway' do
        expect(Spree::Gateway::Amazon.for_currency('GBP')).to eq(gbp_active_gateway)
      end
    end

    context 'when the currency exists but is not active' do
      let!(:gbp_inactive_gateway) { create(:amazon_gateway, active: false, preferred_currency: 'GBP') }

      it 'returns nil' do
        expect(Spree::Gateway::Amazon.for_currency('GBP')).to eq(nil)
      end
    end

    context 'when the currency does not exist' do
      it 'returns nil' do
        expect(Spree::Gateway::Amazon.for_currency('ABC')).to eq(nil)
      end
    end
  end

  describe '#api_url' do
    let(:gbp_gateway) { create(:amazon_gateway, preferred_region: 'uk') }
    let(:usd_gateway) { create(:amazon_gateway, preferred_region: 'us') }
    it 'generates the url based on the region' do
      expect(gbp_gateway.api_url).not_to eq(usd_gateway.api_url)
    end
  end

  describe '#widgets_url' do
    let(:gbp_gateway) { create(:amazon_gateway, preferred_region: 'uk') }
    let(:usd_gateway) { create(:amazon_gateway, preferred_region: 'us') }
    it 'generates the url based on the region' do
      expect(gbp_gateway.widgets_url).not_to eq(usd_gateway.widgets_url)
    end
  end

  def build_mws_auth_response(state:, total:)
    {
      "AuthorizeResponse" => {
        "AuthorizeResult" => {
          "AuthorizationDetails" => {
            "AmazonAuthorizationId" => "
              P01-1234567-1234567-0000001
            ",
            "AuthorizationReferenceId" => "test_authorize_1",
            "SellerAuthorizationNote" => "Lorem ipsum",
            "AuthorizationAmount"=> {
              "CurrencyCode" => "USD",
              "Amount" => total
            },
            "AuthorizationFee" => {
              "CurrencyCode" => "USD",
              "Amount" => "0"
            },
            "AuthorizationStatus" => {
              "State"=> state,
              "LastUpdateTimestamp" => "2012-11-03T19:10:16Z"
            },
            "CreationTimestamp" => "2012-11-02T19:10:16Z",
            "ExpirationTimestamp" => "2012-12-02T19:10:16Z"
          }
        },
        "ResponseMetadata" => { "RequestId": "b4ab4bc3-c9ea-44f0-9a3d-67cccef565c6" }
      }
    }
  end

  def build_mws_capture_response(state:, total:)
    {
      "CaptureResponse" => {
        "CaptureResult" => {
          "CaptureDetails" => {
            "AmazonCaptureId" => "P01-1234567-1234567-0000002",
            "CaptureReferenceId" => "test_capture_1",
            "SellerCaptureNote" => "Lorem ipsum",
            "CaptureAmount" => {
              "CurrencyCode" => "USD",
              "Amount" => total
            },
            "CaptureStatus" => {
              "State" => state,
              "LastUpdateTimestamp" => "2012-11-03T19:10:16Z"
            },
            "CreationTimestamp" => "2012-11-03T19:10:16Z"
          }
        },
        "ResponseMetadata" => { "RequestId" => "b4ab4bc3-c9ea-44f0-9a3d-67cccef565c6" }
      }
    }
  end

  def build_mws_refund_response(state:, total:)
    {
      "RefundResponse" => {
        "RefundResult" => {
          "RefundDetails" => {
            "AmazonRefundId" => "P01-1234567-1234567-0000003",
            "RefundReferenceId" => "test_refund_1",
            "SellerRefundNote" => "Lorem ipsum",
            "RefundType" => "SellerInitiated",
           "RefundedAmount" => {
              "CurrencyCode" => "USD",
              "Amount" => total
            },
            "FeeRefunded" => {
              "CurrencyCode" => "USD",
              "Amount" => "0"
            },
            "RefundStatus" => {
              "State" => state,
              "LastUpdateTimestamp" => "2012-11-07T19:10:16Z"
            },
            "CreationTimestamp" => "2012-11-05T19:10:16Z"
          }
        },
        "ResponseMetadata" => { "RequestId" => "b4ab4bc3-c9ea-44f0-9a3d-67cccef565c6" }
      }
    }
  end

  def build_mws_void_response
    {
      "CancelOrderReferenceResponse" => {
        "CancelOrderReferenceResult"=> nil,
        "ResponseMetadata" => { "RequestId" => "b4ab4bc3-c9ea-44f0-9a3d-67cccef565c6" }
      }
    }
  end
    
  def stub_mws
    mws = instance_double(AmazonMws)
    allow(AmazonMws).to receive(:new).and_return(mws)
    mws
  end

  def create_gateway
    described_class.create!(name: 'Amazon', preferred_test_mode: true)
  end
end

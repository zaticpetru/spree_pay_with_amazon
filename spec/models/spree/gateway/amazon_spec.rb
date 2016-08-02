require 'spec_helper'

describe Spree::Gateway::Amazon do
  let(:payment_method) do
    create(:amazon_gateway,
      preferred_client_id: '',
      preferred_merchant_id: '',
      preferred_aws_access_key_id: '',
      preferred_aws_secret_access_key: '',
    )
  end
  let(:order) { create(:order_with_line_items, state: 'delivery') }
  let(:payment_source) { Spree::AmazonTransaction.create!(order_id: order.id, order_reference: 'REFERENCE') }
  let!(:payment) do
    create(:payment,
           order: order,
           payment_method: payment_method,
           source: payment_source,
           amount: order.total)
  end
  let(:mws) { payment_method.send(:load_amazon_mws, 'REFERENCE') }
  
  describe "#credit" do
    it "calls refund on mws with the correct parameters" do
      amazon_transaction = create(:amazon_transaction, capture_id: "CAPTURE_ID")
      payment = create(:payment, source: amazon_transaction, amount: 30.0, payment_method: payment_method)
      refund = create(:refund, payment: payment, amount: 30.0)
      allow(mws).to receive(:refund).and_return({})

      payment_method.credit(3000, nil, { originator: refund })

      expect(mws).to have_received(:refund).with("CAPTURE_ID", /^#{payment.number}-\w+$/, 30.0, "USD")
    end

    let!(:refund) { create(:refund, payment: payment, amount: payment.amount) }
      it 'succeeds' do
      response = build_mws_refund_response(state: 'Pending', total: order.total)
      expect(mws).to(
        receive(:authorize).
          with(/^#{payment.number}-\w+$/, order.total/100.0, "USD").
          and_return(response)
      )

      auth = payment_method.credit(order.total, payment_source, { originator: refund })
      expect(auth).to be_success
    end
  end

  describe '#purchase' do
    context 'when authorization fails' do
      let(:auth_result) { ActiveMerchant::Billing::Response.new(false, 'Error') }

      it 'returns the authorization result' do
        expect(payment_method).to receive(:authorize).and_return(auth_result)
        expect(payment_method).not_to receive(:capture)

        result = payment_method.purchase(order.total, payment_source, {order_id: payment.send(:gateway_order_id)})
        expect(result).to eq(auth_result)
      end
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

  def build_mws_void_response
    {
      "CancelOrderReferenceResponse" => {
        "CancelOrderReferenceResult"=> nil,
        "ResponseMetadata" => { "RequestId" => "b4ab4bc3-c9ea-44f0-9a3d-67cccef565c6" }
      }
    }
  end
end

require 'spec_helper'

describe Spree::Gateway::Amazon do
  describe "#credit" do
    it "calls credit on mws with the correct parameters" do
      gateway = create_gateway
      mws = stub_mws
      amazon_transaction = create(:amazon_transaction, capture_id: "CAPTURE_ID")
      payment = create(:payment, source: amazon_transaction, amount: 30.0, payment_method: gateway)
      refund = create(:refund, payment: payment, amount: 30.0)
      allow(mws).to receive(:refund).and_return({})

      gateway.credit(3000, nil, { originator: refund })

      expect(mws).to have_received(:refund).with("CAPTURE_ID", payment.number, 30.0, "USD")
    end
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

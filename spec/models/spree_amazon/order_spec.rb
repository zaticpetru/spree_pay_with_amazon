require 'spec_helper'

describe SpreeAmazon::Order do
  before { Spree::Gateway::Amazon.create!(name: 'Amazon', preferred_test_mode: true) }
  describe '.find' do
    it "retrieves an order from MWS" do
      mws = stub_mws('ORDER_REFERENCE')
      response = build_mws_response(
        state: 'Closed',
        total: 10.0,
        email: 'jane@doe.com',
        reference_id: 'ORDER_REFERENCE'
      )
      allow(mws).to receive(:fetch_order_data).and_return(response)

      order = SpreeAmazon::Order.find('ORDER_REFERENCE')

      expect(order.reference_id).to eq('ORDER_REFERENCE')
      expect(order.email).to eq('jane@doe.com')
      expect(order.state).to eq('Closed')
      expect(order.total.money.to_f).to eq(10.0)
    end
  end

  describe '#fetch' do
    it "loads the order information from MWS" do
      order = build_order
      mws = stub_mws(order.reference_id)
      response = build_mws_response(
        state: 'Open',
        total: 30.0,
        email: 'joe@doe.com',
        reference_id: order.reference_id
      )
      allow(mws).to receive(:fetch_order_data).and_return(response)

      order.fetch

      expect(order.email).to eq('joe@doe.com')
      expect(order.state).to eq('Open')
      expect(order.total.money.to_f).to eq(30.0)
    end
  end

  describe '#confirm' do
    it "confirms the order using MWS" do
      order = build_order
      mws = stub_mws(order.reference_id)
      allow(mws).to receive(:confirm_order)

      order.confirm

      expect(mws).to have_received(:confirm_order)
    end
  end

  describe '#save_total' do
    it "saves the order details using MWS" do
      order = build_order(total: 20.0, currency: 'USD')
      mws = stub_mws(order.reference_id)
      allow(mws).to receive(:set_order_data)

      order.save_total

      expect(mws).to have_received(:set_order_data).with(20.0, 'USD')
    end
  end

  def build_mws_response(state:, email:, total:, reference_id:)
    AmazonMwsOrderResponse.new(
      "GetOrderReferenceDetailsResponse" =>{
        "GetOrderReferenceDetailsResult"=> {
          "OrderReferenceDetails"=> {
            "OrderReferenceStatus"=> {
              "LastUpdateTimestamp"=>"2016-04-18T17:05:52.621Z", "State"=>state
            },
            "Destination"=> {
              "DestinationType"=>"Physical",
              "PhysicalDestination"=> {}
            },
            "ExpirationTimestamp"=>"2016-10-15T17:05:32.272Z",
            "IdList"=>{"member"=>"S01-4301752-9080047-A018166"},
            "SellerOrderAttributes"=>nil,
            "OrderTotal"=>{"CurrencyCode"=>'USD', "Amount"=>total},
            "Buyer"=>{"Name"=>"Joe Doe", "Email"=>email},
            "ReleaseEnvironment"=>"Sandbox",
            "AmazonOrderReferenceId"=>reference_id,
            "CreationTimestamp"=>"2016-04-18T17:05:32.272Z",
            "RequestPaymentAuthorization"=>"false"
          }
        },
        "ResponseMetadata"=>{"RequestId"=>"f390f7fb-0cdc-486c-974b-0db919cf82b3"}
      }
    )
  end

  def build_order(attributes = {})
    defaults = { reference_id: 'ORDER_REFERENCE' }
    described_class.new defaults.merge(attributes)
  end

  def stub_mws(order_reference)
    mws = instance_double(AmazonMws)
    allow(AmazonMws).to receive(:new).with(order_reference, true)
                                     .and_return(mws)
    mws
  end
end

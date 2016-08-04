require 'spec_helper'

describe SpreeAmazon::Order do

  let!(:gateway) do
    create(:amazon_gateway,
      preferred_currency: 'USD',
      preferred_client_id: '',
      preferred_merchant_id: '',
      preferred_aws_access_key_id: '',
      preferred_aws_secret_access_key: '',
    )
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

    context 'with an address_consent_token' do
      it 'sends the token in the request' do
        order = build_order(address_consent_token: 'token')
        mws = stub_mws(order.reference_id, address_consent_token: 'token')
        response = build_mws_response(
          state: 'Open',
          total: 30.0,
          email: 'joe@doe.com',
          reference_id: order.reference_id
        )
        allow(mws).to receive(:fetch_order_data).and_return(response)

        order.fetch

        expect(AmazonMws).to have_received(:new).
          with(
            order.reference_id,
            gateway: gateway,
            address_consent_token: 'token',
          )
      end
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

   describe '#set_order_reference_details' do
    let(:order) { build_order(total: 20.0, currency: 'USD') }

    def stub_details_request(return_values:, request_params: {})
      stub_request(
        :post,
        'https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01',
      ).with(
        body: hash_including(
          {
            'Action' => 'SetOrderReferenceDetails',
            'AmazonOrderReferenceId' => 'ORDER_REFERENCE',
            'OrderReferenceAttributes.OrderTotal.CurrencyCode' => order.currency,
          }.merge(request_params)
        )
      ).to_return(
        return_values,
      )
    end

    it "saves the order details using MWS" do
      stub_details_request(
        return_values: {
          status: 200,
          headers: {'content-type' => 'text/xml'},
          body: build_mws_set_order_reference_details_success_response(total: order.total),
        }
      )

      response = order.set_order_reference_details(order.total)

      expect(response.success).to eq(true)
    end

    it "saves additional options using MWS" do
      stub_details_request(
        request_params: {
          'OrderReferenceAttributes.SellerNote' => 'some-seller-note',
          'OrderReferenceAttributes.SellerOrderAttributes.CustomInformation' => 'some-custom-information',
          'OrderReferenceAttributes.SellerOrderAttributes.SellerOrderId' => 'some-seller-order-id',
          'OrderReferenceAttributes.SellerOrderAttributes.StoreName' => 'some-store-name',
        },
        return_values: {
          status: 200,
          headers: {'content-type' => 'text/xml'},
          body: build_mws_set_order_reference_details_success_response(total: order.total),
        }
      )

      response = order.set_order_reference_details(
        order.total,
        seller_note: 'some-seller-note',
        seller_order_id: 'some-seller-order-id',
        store_name: 'some-store-name',
        custom_information: 'some-custom-information',
      )

      expect(response.success).to eq(true)
    end

    context 'when it fails' do
      it 'returns a failure response' do
        stub_details_request(
          return_values: {
            status: 405,
            headers: {'content-type' => 'text/xml'},
            body: build_mws_set_order_reference_details_failure_response,
          }
        )

        response = order.set_order_reference_details(order.total)

        expect(response.success).to eq(false)
      end
     end
  end

  describe '#close_order_reference!' do
    let(:order) { build_order }

    def stub_close_request(return_values:)
      stub_request(
        :post,
        'https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01',
      ).with(
        body: hash_including(
          'Action' => 'CloseOrderReference',
          'AmazonOrderReferenceId' => 'ORDER_REFERENCE',
        )
      ).to_return(
        return_values,
      )
    end

    context 'when successful' do
      it 'returns a success response' do
        stub_close_request(
          return_values: {
            status: 200,
            headers: {'content-type' => 'text/xml'},
            body: build_mws_close_order_reference_success_response,
          },
        )

        result = order.close_order_reference!

        expect(result).to be_truthy
      end
    end

    context 'when failed' do
      it 'returns a failure response' do
        stub_close_request(
          return_values: {
            status: 404,
            headers: {'content-type' => 'text/xml'},
            body: build_mws_close_order_reference_failure_response,
          },
        )

        expect {
          order.close_order_reference!
        }.to raise_error(SpreeAmazon::Order::CloseFailure)
      end
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

  def build_mws_close_order_reference_success_response
    <<-XML.strip_heredoc
      <CloseOrderReferenceResponse xmlns="http://mws.amazonservices.com/schema/OffAmazonPayments/2013-01-01">
        <CloseOrderReferenceResult/>
        <ResponseMetadata>
          <RequestId>2766cf23-f468-4800-bdaf-4bd67c7799e5</RequestId>
        </ResponseMetadata>
      </CloseOrderReferenceResponse>
    XML
  end

  def build_mws_close_order_reference_failure_response
    <<-XML.strip_heredoc
      <ErrorResponse xmlns="http://mws.amazonservices.com/schema/OffAmazonPayments/2013-01-01">
        <Error>
          <Type>Sender</Type>
          <Code>InvalidOrderReferenceId</Code>
          <Message>The OrderReferenceId ORDER_REFERENCE is invalid.</Message>
        </Error>
        <RequestId>f16e027d-4a2e-463f-b60c-0c7f61b13be7</RequestId>
      </ErrorResponse>
    XML
  end

  def build_mws_set_order_reference_details_success_response(total:)
    <<-XML.strip_heredoc
      <SetOrderReferenceDetailsResponse xmlns="http://mws.amazonservices.com/schema/OffAmazonPayments/2013-01-01">
        <SetOrderReferenceDetailsResult>
          <OrderReferenceDetails>
            <OrderReferenceStatus>
              <State>Draft</State>
            </OrderReferenceStatus>
            <OrderLanguage>en-GB</OrderLanguage>
            <Destination>
              <DestinationType>Physical</DestinationType>
              <PhysicalDestination>
                <City>London</City>
                <CountryCode>GB</CountryCode>
                <PostalCode>W2 4RJ</PostalCode>
              </PhysicalDestination>
            </Destination>
            <ExpirationTimestamp>2017-01-31T20:18:49.767Z</ExpirationTimestamp>
            <SellerOrderAttributes/>
            <OrderTotal>
              <CurrencyCode>USD</CurrencyCode>
              <Amount>#{total}</Amount>
            </OrderTotal>
            <ReleaseEnvironment>Sandbox</ReleaseEnvironment>
            <AmazonOrderReferenceId>S02-4397435-2281620</AmazonOrderReferenceId>
            <CreationTimestamp>2016-08-04T20:18:49.767Z</CreationTimestamp>
            <RequestPaymentAuthorization>false</RequestPaymentAuthorization>
          </OrderReferenceDetails>
        </SetOrderReferenceDetailsResult>
        <ResponseMetadata>
          <RequestId>4df5e1b5-51ec-4d9c-8940-28c016a8bbed</RequestId>
        </ResponseMetadata>
      </SetOrderReferenceDetailsResponse>
    XML
  end

  def build_mws_set_order_reference_details_failure_response
    <<-XML.strip_heredoc
      <ErrorResponse xmlns="http://mws.amazonservices.com/schema/OffAmazonPayments/2013-01-01">
        <Error>
          <Type>Sender</Type>
          <Code>OrderReferenceNotModifiable</Code>
          <Message>OrderReference ORDER_REFERENCE is not in draft state and cannot be modified with the request submitted by you.</Message>
        </Error>
        <RequestId>4a23e06f-338f-a495-a463-f2eb1a537a9f</RequestId>
      </ErrorResponse>
    XML
  end

  def build_order(attributes = {})
    defaults = { reference_id: 'ORDER_REFERENCE', gateway: gateway }
    described_class.new defaults.merge(attributes)
  end

  def stub_mws(order_reference, address_consent_token: nil)
    mws = instance_double(AmazonMws)
    allow(AmazonMws).to receive(:new).
      with(
        order_reference,
        gateway: gateway,
        address_consent_token: address_consent_token,
      ).
      and_return(mws)
    mws
  end
end

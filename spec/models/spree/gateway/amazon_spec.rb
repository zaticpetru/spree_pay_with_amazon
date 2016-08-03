require 'spec_helper'

describe Spree::Gateway::Amazon do
  let(:payment_method) { Spree::Gateway::Amazon.for_currency(order.currency) }
  let!(:amazon_gateway) do
    create(:amazon_gateway,
      preferred_currency: 'USD',
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

  describe '#authorize' do
    def stub_auth_request(expected_body: nil, return_values: nil)
      stub_request(
        :post,
        'https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01',
      ).with(
        body: expected_body || hash_including(
          'Action' => 'Authorize',
          'AmazonOrderReferenceId' => 'REFERENCE',
          'AuthorizationAmount.Amount' => '1.1',
          'AuthorizationAmount.CurrencyCode' => order.currency
        )
      ).to_return(
        return_values || {
          headers: {'content-type' => 'text/xml'},
          body: build_mws_auth_approved_response(order: order),
        },
      )
    end

    context 'when approved' do
      it 'succeeds' do
        stub_auth_request

        response = payment_method.authorize(order.total, payment_source, {order_id: payment.send(:gateway_order_id)})

        expect(response).to be_success
      end
    end

    context 'when declined' do
      it 'fails' do
        stub_auth_request(return_values: {
          headers: {'content-type' => 'text/xml'},
          status: 200,
          body: build_mws_auth_declined_response(order: order),
        })

        response = payment_method.authorize(order.total, payment_source, {order_id: payment.send(:gateway_order_id)})

        expect(response).not_to be_success
        expect(response.message).to eq('Authorization failure: InvalidPaymentMethod')
      end
    end

    context 'with an ErrorResponse error' do
      it 'fails' do
        stub_auth_request(return_values: {
          headers: {'content-type' => 'text/xml'},
          status: 400,
          body: build_mws_auth_error_response(order: order),
        })

        response = payment_method.authorize(order.total, payment_source, {order_id: payment.send(:gateway_order_id)})

        expect(response).not_to be_success
        expect(response.message).to match(/^400 TransactionAmountExceeded:/)
      end
    end

    context 'with a 5xx error' do
      it 'fails' do
        stub_auth_request(return_values: {
          headers: {'content-type' => 'text/plain'},
          status: 502,
          body: 'Bad Gateway',
        })

        response = payment_method.authorize(order.total, payment_source, {order_id: payment.send(:gateway_order_id)})

        expect(response).not_to be_success
        expect(response.message).to match(/502 Bad Gateway/)
      end
    end

    # 500 is special-cased in the Amazon library
    context 'with a 500 error' do
      it 'fails' do
        stub_auth_request(return_values: {
          headers: {'content-type' => 'text/plain'},
          status: 500,
          body: 'Server Error',
        })

        expect {
          response = payment_method.authorize(order.total, payment_source, {order_id: payment.send(:gateway_order_id)})
        }.to raise_error(Spree::Core::GatewayError, 'InternalServerError')
      end
    end

    # 503 is special-cased in the Amazon library
    context 'with a 503 error' do
      before do
        # Without this the specs have a big pause while the Amazon gem retries
        allow_any_instance_of(PayWithAmazon::Request).to receive(:get_seconds_for_try_count).and_return(0)
      end

      it 'fails' do
        stub_auth_request(return_values: {
          headers: {'content-type' => 'text/plain'},
          status: 503,
          body: 'Service Unavailable',
        })

        expect {
          response = payment_method.authorize(order.total, payment_source, {order_id: payment.send(:gateway_order_id)})
        }.to raise_error(Spree::Core::GatewayError, 'ServiceUnavailable or RequestThrottled')
      end
    end

    context 'with sandbox simulation strings' do
      context 'with a ship address' do
        let(:order) { create(:order_with_line_items, state: 'delivery', ship_address: ship_address) }
        let(:ship_address) do
          create(:address,
            firstname: 'InvalidPaymentMethodHard',
            lastname: 'SandboxSimulation',
          )
        end
        let(:expected_note) { '{"SandboxSimulation": {"State":"Declined", "ReasonCode":"InvalidPaymentMethod", "PaymentMethodUpdateTimeInMins":1}}' }

        it 'forwards the note to Amazon' do
          allow(mws).to receive(:authorize).and_call_original

          stub_auth_request(
            expected_body: hash_including(
              'Action' => 'Authorize',
              'SellerAuthorizationNote' => expected_note,
            ),
          )

          payment_method.authorize(order.total, payment_source, {order_id: payment.send(:gateway_order_id)})

          expect(mws).to have_received(:authorize).with(
            /^#{payment.number}-\w+$/,
            order.total/100,
            order.currency,
            seller_authorization_note: expected_note,
          )
        end
      end

      context 'without a ship address' do
        before do
          order.update_attributes!(ship_address: nil)
        end

        it 'does not forward a note to Amazon' do
          allow(mws).to receive(:authorize).and_call_original

          stub_auth_request

          payment_method.authorize(order.total, payment_source, {order_id: payment.send(:gateway_order_id)})

          expect(mws).to have_received(:authorize).with(
            /^#{payment.number}-\w+$/,
            order.total/100,
            order.currency,
            seller_authorization_note: nil,
          )
        end
      end
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

  def build_mws_auth_approved_response(
    order:,
    authorization_reference_id: 'some-authorization-reference-id',
    amazon_authorization_id: 'some-amazon-authorization-id'
  )
    <<-XML.strip_heredoc
      <AuthorizeResponse xmlns="http://mws.amazonservices.com/schema/OffAmazonPayments/2013-01-01">
        <AuthorizeResult>
          <AuthorizationDetails>
            <AuthorizationAmount>
              <CurrencyCode>#{order.currency}</CurrencyCode>
              <Amount>#{order.total}</Amount>
            </AuthorizationAmount>
            <CapturedAmount>
              <CurrencyCode>#{order.currency}</CurrencyCode>
              <Amount>0</Amount>
            </CapturedAmount>
            <ExpirationTimestamp>2016-08-31T20:05:26.104Z</ExpirationTimestamp>
            <IdList/>
            <SoftDecline>false</SoftDecline>
            <AuthorizationStatus>
              <LastUpdateTimestamp>2016-08-01T20:05:26.104Z</LastUpdateTimestamp>
              <State>Open</State>
            </AuthorizationStatus>
            <AuthorizationFee>
              <CurrencyCode>#{order.currency}</CurrencyCode>
              <Amount>0.00</Amount>
            </AuthorizationFee>
            <AuthorizationBillingAddress>
              <Name>Jordan Brough</Name>
              <AddressLine1>1234 Way</AddressLine1>
              <City>Beverly Hills</City>
              <PostalCode>90210</PostalCode>
              <CountryCode>US</CountryCode>
            </AuthorizationBillingAddress>
            <CaptureNow>false</CaptureNow>
            <CreationTimestamp>2016-08-01T20:05:26.104Z</CreationTimestamp>
            <SellerAuthorizationNote/>
            <AmazonAuthorizationId>#{amazon_authorization_id}</AmazonAuthorizationId>
            <AuthorizationReferenceId>#{authorization_reference_id}</AuthorizationReferenceId>
          </AuthorizationDetails>
        </AuthorizeResult>
        <ResponseMetadata>
          <RequestId>2a7ec86e-ac87-45b4-aba9-245392e707c4</RequestId>
        </ResponseMetadata>
      </AuthorizeResponse>
    XML
  end

  def build_mws_auth_declined_response(
    order:,
    authorization_reference_id: 'some-authorization-reference-id',
    amazon_authorization_id: 'some-amazon-authorization-id'
  )
    <<-XML.strip_heredoc
      <AuthorizeResponse xmlns="http://mws.amazonservices.com/schema/OffAmazonPayments/2013-01-01">
        <AuthorizeResult>
          <AuthorizationDetails>
            <AuthorizationAmount>
              <CurrencyCode>#{order.currency}</CurrencyCode>
              <Amount>#{order.total}</Amount>
            </AuthorizationAmount>
            <CapturedAmount>
              <CurrencyCode>#{order.currency}</CurrencyCode>
              <Amount>0</Amount>
            </CapturedAmount>
            <ExpirationTimestamp>2016-08-31T20:03:42.608Z</ExpirationTimestamp>
            <SoftDecline>false</SoftDecline>
            <AuthorizationStatus>
              <LastUpdateTimestamp>2016-08-01T20:03:42.608Z</LastUpdateTimestamp>
              <State>Declined</State>
              <ReasonCode>InvalidPaymentMethod</ReasonCode>
            </AuthorizationStatus>
            <AuthorizationFee>
              <CurrencyCode>#{order.currency}</CurrencyCode>
              <Amount>0.00</Amount>
            </AuthorizationFee>
            <CaptureNow>false</CaptureNow>
            <CreationTimestamp>2016-08-01T20:03:42.608Z</CreationTimestamp>
            <SellerAuthorizationNote>{&quot;SandboxSimulation&quot;: {&quot;State&quot;:&quot;Declined&quot;, &quot;ReasonCode&quot;:&quot;InvalidPaymentMethod&quot;, &quot;PaymentMethodUpdateTimeInMins&quot;:1}}</SellerAuthorizationNote>
            <AmazonAuthorizationId>#{amazon_authorization_id}</AmazonAuthorizationId>
            <AuthorizationReferenceId>#{authorization_reference_id}</AuthorizationReferenceId>
          </AuthorizationDetails>
        </AuthorizeResult>
        <ResponseMetadata>
          <RequestId>b86614ce-2f63-4186-961e-e6548cdc509f</RequestId>
        </ResponseMetadata>
      </AuthorizeResponse>
    XML
  end

  def build_mws_auth_error_response(order:)
    <<-XML.strip_heredoc
      <ErrorResponse xmlns="http://mws.amazonservices.com/schema/OffAmazonPayments/2013-01-01">
        <Error>
          <Type>Sender</Type>
          <Code>TransactionAmountExceeded</Code>
          <Message>An Authorization request with amount 1000.00 USD cannot be accepted. The total Authorization amount against the OrderReference some-order-reference-id cannot exceed #{order.total} #{order.currency}.</Message>
        </Error>
        <RequestId>afca042f-0f64-ba8c-89b1-9be261bc7381</RequestId>
      </ErrorResponse>
    XML
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

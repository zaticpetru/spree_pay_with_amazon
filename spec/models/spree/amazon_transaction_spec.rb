require 'spec_helper'

describe Spree::AmazonTransaction do
  let(:payment_method) { Spree::Gateway::Amazon.create!(name: 'Amazon', preferred_test_mode: true) }
  let(:order) { create(:order_with_line_items, state: 'delivery') }
  let(:amazon_transaction) { Spree::AmazonTransaction.create!(order_id: order.id, order_reference: 'REFERENCE') }
  let!(:payment) do
    create(:payment,
           order: order,
           payment_method: payment_method,
           source: amazon_transaction,
           amount: order.total)
  end

  describe '#name' do
    it 'equals is Pay with Amazon' do
      expect(amazon_transaction.name).to eq('Pay with Amazon')
    end
  end

  describe '#cc_type' do
    it 'equals n/a' do
      expect(amazon_transaction.cc_type).to eq('n/a')
    end
  end

  describe '#month' do
    it 'equals n' do
      expect(amazon_transaction.month).to eq('n')
    end
  end

  describe '#year' do
    it 'equals a' do
      expect(amazon_transaction.year).to eq('a')
    end
  end

  describe '#reusable_sources' do
    it 'returns empty array' do
      expect(amazon_transaction.reusable_sources(order)).to eq([])
    end
  end

  describe '#with_payment_profile' do
    it 'returns empty array' do
      expect(Spree::AmazonTransaction.with_payment_profile).to eq([])
    end
  end

  describe '#can_capture?' do
    it 'should be true if payment is pending' do
      expect(amazon_transaction.can_capture?(payment)).to be true
    end

    it 'should be true if payment is checkout' do
      expect(amazon_transaction.can_capture?(payment)).to be true
    end
  end

  describe '#can_credit?' do
    it 'should be false if payment is not completed' do
      expect(amazon_transaction.can_credit?(payment)).to be false
    end

    it 'should be false when credit_allowed is zero' do
      expect(amazon_transaction.can_credit?(payment)).to be false
    end
  end

  describe '#can_void?' do
    it 'should be true if payment is in pending state' do
      payment.update_attributes(state: 'pending')
      expect(amazon_transaction.can_void?(payment)).to be true
    end

    it 'should be false if payment is in complete state' do
      payment.update_attributes(state: 'completed')
      expect(amazon_transaction.can_void?(payment)).to be false
    end
  end

  describe '#can_close?' do
    it 'should be true if payment is in complete state' do
      payment.update_attributes(state: 'completed')
      amazon_transaction.update_attributes(closed_at: nil)

      expect(amazon_transaction.can_close?(payment)).to be true
    end

    it 'should be false if payment is in pending state' do
      payment.update_attributes(state: 'pending')

      expect(amazon_transaction.can_close?(payment)).to be false
    end

    it 'should be false if closed_at is not nil' do
      amazon_transaction.update_attributes(closed_at: DateTime.now)

      expect(amazon_transaction.can_close?(payment)).to be false
    end
  end

  describe '#actions' do
    it 'should include capture' do
      expect(amazon_transaction.actions).to include('capture')
    end
    it 'should include credit' do
      expect(amazon_transaction.actions).to include('credit')
    end
    it 'should include void' do
      expect(amazon_transaction.actions).to include('void')
    end
    it 'should include close' do
      expect(amazon_transaction.actions).to include('close')
    end
  end

  describe '#close!' do
    it 'returns true if payment is not completed' do
      payment = create(:amazon_payment, state: 'pending')
      source = payment.source

      expect(source.close!(payment)).to be_truthy
    end

    it 'returns true if closed_at is not nil' do
      payment = create(:amazon_payment, state: 'completed')
      source = payment.source
      source.update_attributes(closed_at: DateTime.now)

      expect(source.close!(payment)).to be_truthy
    end

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
      it 'returns true' do
        payment = create(:amazon_payment, state: 'completed')
        source = payment.source
        stub_close_request(
          return_values: {
            status: 200,
            headers: {'content-type' => 'text/xml'},
            body: build_mws_close_order_reference_success_response,
          },
        )

        expect(source.close!(payment)).to be_truthy
      end
    end

    context 'when failure' do
      it 'raises Spree::Core::GatewayError' do
        payment = create(:amazon_payment, state: 'completed')
        source = payment.source
        stub_close_request(
          return_values: {
            status: 404,
            headers: {'content-type' => 'text/xml'},
            body: build_mws_close_order_reference_failure_response,
          },
        )

        expect {
          source.close!(payment)
        }.to raise_error(Spree::Core::GatewayError)
      end
    end
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
end
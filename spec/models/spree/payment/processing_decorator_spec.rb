require 'spec_helper'

describe Spree::Payment::Processing do
  describe '#close!' do
    it 'returns true if payment is already closed' do
      payment = create(:amazon_payment, state: 'completed')
      payment.source.update_attributes(closed_at: DateTime.now)

      expect(payment.close!).to be_truthy
    end

    it 'returns true if payment is not an AmazonTransaction' do
      payment = create(:payment)

      expect(payment.close!).to be_truthy
    end

    it 'payment receives close! method' do
      payment = create(:amazon_payment, state: 'completed')

      expect(payment).to receive(:close!)

      payment.close!
    end

    it 'delegates close! to the payment source' do
      payment = create(:amazon_payment, state: 'completed')
      allow_any_instance_of(Spree::AmazonTransaction).to receive(:close!)

      payment.close!

      expect(payment.source).to have_received(:close!)
    end
  end

  def stub_close_request
    stub_request(
      :post,
      'https://mws.amazonservices.com/OffAmazonPayments_Sandbox/2013-01-01',
    ).with(
      body: hash_including(
        'Action' => 'CloseOrderReference',
        'AmazonOrderReferenceId' => 'ORDER_REFERENCE',
      )
    ).to_return(
      {
        status: 200,
        headers: {'content-type' => 'text/xml'},
        body: build_mws_close_order_reference_success_response,
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
end
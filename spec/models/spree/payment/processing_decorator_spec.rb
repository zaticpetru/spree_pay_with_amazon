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
  end
end
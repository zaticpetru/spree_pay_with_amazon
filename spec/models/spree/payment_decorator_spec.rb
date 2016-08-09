require 'spec_helper'

describe Spree::Payment, type: :model do
  describe '#amazon_transaction?' do
    it 'returns true if source_type is Spree::AmazonTransaction' do
      payment = create(:amazon_payment)

      expect(payment.amazon_transaction?).to be_truthy
    end

    it 'returns false if source_type is not Spree::AmazonTransaction' do
      payment = create(:payment)

      expect(payment.amazon_transaction?).to be_falsey
    end
  end
end
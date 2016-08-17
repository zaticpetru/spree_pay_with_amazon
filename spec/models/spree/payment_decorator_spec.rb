require 'spec_helper'

describe Spree::Payment, type: :model do
  describe '#amazon' do
    it 'returns all amazon payments' do
       payment = create(:amazon_payment)

      expect(Spree::Payment.amazon).to include(payment)
     end

    it 'does not include non amazon payments' do
       payment = create(:payment)

      expect(Spree::Payment.amazon).to_not include(payment)
     end
   end
end
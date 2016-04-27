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
      payment.update_attributes(state: 'complete')
      expect(amazon_transaction.can_void?(payment)).to be false
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
  end
end
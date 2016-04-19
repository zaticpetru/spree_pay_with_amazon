require 'spec_helper'

describe Spree::AmazonController do
  describe "GET #address" do
    it "sets the order to the cart state" do
      order = create(:order_with_totals, state: 'address')
      set_current_order(order)

      spree_get :address

      expect(order.reload.cart?).to be true
    end

    it "redirects if there's no current order" do
      spree_get :address

      expect(response).to redirect_to('/')
    end

    it "redirects if there's no amazon order reference id" do

    end
  end

  describe 'POST #delivery' do
    context "when the user has selected an amazon address" do
      let!(:us) { create(:country, iso: 'US') }
      let!(:ny) {create(:state, abbr: 'NY', country: us) }

      it "associates that address with the order" do
        order = create(:order_with_line_items)
        address = build_amazon_address(
          city: "New York",
          state_name: "NY",
          country_code: "US",
          zipcode: "10012"
        )
        set_current_order(order)
        select_amazon_address(address)

        spree_post :delivery

        [order.ship_address, order.bill_address].each do |address|
          expect(address.city).to eq("New York")
          expect(address.zipcode).to eq("10012")
          expect(address.country).to eq(us)
          expect(address.state_text).to eq("NY")
        end
      end

      it "moves the order to the delivery state" do
        order = create(:order_with_line_items)
        address = build_amazon_address
        set_current_order(order)
        select_amazon_address(address)

        spree_post :delivery

        expect(order.delivery?).to be true
      end
    end

    context "when the user hasn't selected an amazon address" do
      it "redirects to the address action" do
        order = create(:order_with_totals)
        set_current_order(order)
        select_amazon_address(nil)

        spree_post :delivery

        expect(response).to redirect_to('/amazon_order/address')
      end

      it "displays a flash message" do
        order = create(:order_with_totals)
        set_current_order(order)
        select_amazon_address(nil)

        spree_post :delivery

        expect(flash[:notice]).to eq("Unable to load Address data from Amazon")
      end
    end
  end

  describe "#POST payment" do
    context "when the order doesn't have an amazon payment" do
      it "creates a new payment" do
        order = create(:order_with_totals)
        set_current_order(order)

        expect {
          spree_post :payment, order_reference: 'ORDER_REFERENCE'
        }.to change(order.payments, :count).by(1)
      end
    end

    it "sets the correct attributes on the payment" do
      Spree::Gateway::Amazon.create!(name: 'Amazon')
      order = create(:order_with_totals)
      set_current_order(order)

      spree_post :payment, order_reference: 'ORDER_REFERENCE'

      payment = order.payments.amazon.first
      transaction = payment.source
      expect(payment.number).to eq('ORDER_REFERENCE')
      expect(payment.payment_method).to be_a(Spree::Gateway::Amazon)
      expect(transaction.order_reference).to eq('ORDER_REFERENCE')
      expect(transaction.order_id).to eq(order.id)
    end
  end

  def build_amazon_address(attributes = {})
    defaults = {
      city: "New York",
      state_name: "NY",
      country_code: "US",
      zipcode: "10012"
    }
    SpreeAmazon::Address.new defaults.merge(attributes)
  end

  def select_amazon_address(address)
    allow(SpreeAmazon::Address).to receive(:find).and_return(address)
  end

  def set_current_order(order)
    order.amazon_transactions.create(order_reference: 'ORDER_REFERENCE')
    allow(controller).to receive(:current_order).and_return(order)
  end
end

require 'spec_helper'

describe Spree::AmazonController do
  describe "GET #address" do
    it "sets the order to the cart state" do
      order = create(:order_with_totals, state: 'address')
      set_current_order(order)

      spree_get :address

      expect(order.reload.cart?).to be true
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
    allow(controller).to receive(:current_order).and_return(order)
  end
end

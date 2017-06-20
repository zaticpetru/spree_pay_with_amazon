require 'spec_helper'

describe Spree::AmazonController do
  let!(:gateway) { create(:amazon_gateway) }

  describe "GET #address" do
    it "sets the order to the address state" do
      order = create(:order_with_totals, state: 'cart')
      set_current_order(order)

      get :address

      expect(order.reload.address?).to be true
    end

    it "redirects if there's no current order" do
      get :address

      expect(response).to redirect_to('/')
    end
  end

  describe 'POST #delivery' do
    context "when the user has selected an amazon address" do
      let!(:us) { create(:country, iso: 'US') }
      let!(:ny) {create(:state, abbr: 'NY', country: us) }

      it "associates that address with the order" do
        order = create(:order_with_line_items, ship_address: create(:address))
        address = build_amazon_address(
          city: "New York",
          state_name: "NY",
          country_code: "US",
          zipcode: "10012"
        )
        set_current_order(order)
        select_amazon_address(address)

        post :delivery

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

        post :delivery

        expect(order.reload.delivery?).to be true
      end
    end

    context "when the user hasn't selected an amazon address" do
      it "redirects to the address action" do
        order = create(:order_with_totals)
        set_current_order(order)
        select_amazon_address(nil)

        post :delivery

        expect(response).to redirect_to('/amazon_order/address')
      end

      it "displays a flash message" do
        order = create(:order_with_totals)
        set_current_order(order)
        select_amazon_address(nil)

        post :delivery

        expect(flash[:notice]).to eq("Unable to load Address data from Amazon")
      end
    end
  end

  describe "POST #confirm" do
    it "sets the correct amount on the payment" do
      order = create(:order_with_line_items, state: 'delivery')
      payment = create_order_payment(order, amount: 10)
      set_current_order(order)
      shipment = order.shipments.first
      shipping_rate = shipment.selected_shipping_rate
      shipment_attributes = build_shipment_attributes(
        id: shipment.id,
        selected_shipping_rate_id: shipping_rate.id
      )

      post :confirm, params: { order: shipment_attributes }

      expect(payment.reload.amount).to eq(order.reload.total)
    end

    it "moves the order to the confirm state" do
      order = create(:order_with_line_items, state: 'delivery')
      payment = create_order_payment(order)
      set_current_order(order)
      shipment = order.shipments.first
      shipping_rate = shipment.selected_shipping_rate
      shipment_attributes = build_shipment_attributes(
        id: shipment.id,
        selected_shipping_rate_id: shipping_rate.id
      )

      post :confirm, params: { order: shipment_attributes }

      expect(order.reload.confirm?).to be true
    end

    it "updates the shipping rate" do
      order = create(:order_with_line_items, state: 'delivery')
      payment = create_order_payment(order)
      set_current_order(order)
      shipment = order.shipments.first
      other_shipping_method = create(:shipping_method, name: 'Other')
      new_shipping_rate = shipment.add_shipping_method(other_shipping_method)
      shipment_attributes = build_shipment_attributes(
        id: shipment.id,
        selected_shipping_rate_id: new_shipping_rate.id
      )

      post :confirm, params: { order: shipment_attributes }

      expect(shipment.reload.selected_shipping_rate).to eq(new_shipping_rate)
    end
  end

  describe "POST #complete" do
    def stub_amazon_order(address: build_amazon_address, email: 'jordan.brough@example.com')
      allow_any_instance_of(SpreeAmazon::Order).to receive(:fetch).and_wrap_original { |method, *args|
        amazon_order = method.receiver
        amazon_order.address = address
        amazon_order.email = email
        amazon_order
      }
      allow_any_instance_of(SpreeAmazon::Order).to receive(:confirm).and_return(nil)
      allow_any_instance_of(SpreeAmazon::Order).to receive(:set_order_reference_details).and_return(nil)
    end

    it "completes the spree order" do
      order = create(:order_with_line_items, state: 'confirm')
      create_order_payment(order)
      set_current_order(order)
      stub_amazon_order

      post :complete

      expect(order.completed?).to be true
    end

    it "saves the total and confirms the order with mws" do
      order = create(:order_with_line_items, state: 'confirm')
      create_order_payment(order)
      stub_amazon_order
      set_current_order(order)

      expect_any_instance_of(SpreeAmazon::Order).to(
        receive(:set_order_reference_details).
        with(
          order.total,
          seller_order_id: order.number,
          store_name: order.store.name,
        ).
        and_return(nil)
      )
      expect_any_instance_of(SpreeAmazon::Order).to receive(:confirm)

      post :complete
    end

    it "updates the shipping address of the order" do
      us = create(:country, iso: 'US')
      ny = create(:state, abbr: 'NY', country: us)
      order = create(:order_with_line_items, state: 'confirm')
      create_order_payment(order)
      address = build_amazon_address(
        name: 'Matt Murdock',
        address1: '224 Lafayette St',
        address2: 'Suite 2',
        city: 'New York',
        state_name: 'NY',
        country_code: 'US',
        zipcode: '10024'
      )
      stub_amazon_order(address: address)
      set_current_order(order)

      post :complete

      address = order.ship_address
      expect(address.firstname).to eq('Matt')
      expect(address.lastname).to eq('Murdock')
      expect(address.address1).to eq('224 Lafayette St')
      expect(address.address2).to eq('Suite 2')
      expect(address.city).to eq('New York')
      expect(address.state_text).to eq('NY')
      expect(address.country).to eq(us)
    end

    context "when the order can't be completed" do
      # Order won't be able to complete as the payment is missing
      it "redirects to the cart page" do
        order = create(:order_with_line_items)
        set_current_order(order)
        stub_amazon_order

        post :complete, params: { order: {} }

        expect(response).to redirect_to('/cart')
      end

      it "sets an error message" do
        order = create(:order_with_line_items)
        set_current_order(order)
        stub_amazon_order

        post :complete, params: { order: {} }

        expect(flash[:notice]).to eq("Unable to process order")
      end
    end
  end

  describe "POST #payment" do
    context "when the order doesn't have an amazon payment" do
      it "creates a new payment" do
        order = create(:order_with_totals)
        set_current_order(order)

        expect {
          post :payment, params: { order_reference: 'ORDER_REFERENCE' }
        }.to change(order.payments, :count).by(1)
      end
    end

    it "sets the correct attributes on the payment" do
      Spree::Gateway::Amazon.create!(name: 'Amazon')
      order = create(:order_with_totals)
      set_current_order(order)

      post :payment, params: { order_reference: 'ORDER_REFERENCE' }

      payment = order.payments.amazon.first
      transaction = payment.source
      expect(payment.payment_method).to be_a(Spree::Gateway::Amazon)
      expect(transaction.order_reference).to eq('ORDER_REFERENCE')
      expect(transaction.order_id).to eq(order.id)
    end
  end

  def create_order_payment(order, amount: nil)
    transaction = Spree::AmazonTransaction.create!(
      order_id: order.id, order_reference: 'REFERENCE'
    )
    order.payments.create!(source: transaction, amount: amount || order.total)
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
    cookies.signed[:guest_token] = order.guest_token
  end

  def build_shipment_attributes(attributes)
    {
      shipments_attributes: [
        attributes
      ]
    }
  end
end


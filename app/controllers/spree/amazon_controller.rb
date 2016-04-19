##
# Amazon Payments - Login and Pay for Spree Commerce
#
# @category    Amazon
# @package     Amazon_Payments
# @copyright   Copyright (c) 2014 Amazon.com
# @license     http://opensource.org/licenses/Apache-2.0  Apache License, Version 2.0
#
##
class Spree::AmazonController < Spree::StoreController
  helper 'spree/orders'
  before_filter :check_current_order
  before_filter :check_amazon_reference_id, only: [:delivery, :confirm]

  respond_to :json

  def address
    current_order.state = 'cart'
    current_order.save!
  end

  def payment
    payment = current_order.payments.amazon.first || current_order.payments.create
    payment.number = params[:order_reference]
    payment.payment_method = Spree::Gateway::Amazon.first
    payment.source ||= Spree::AmazonTransaction.create(
      order_reference: params[:order_reference],
      order_id: current_order.id
    )

    payment.save!

    render json: {}
  end

  def delivery
    current_order.state = 'cart'
    address = SpreeAmazon::Address.find(current_order.amazon_order_reference_id)

    if address
      current_order.email = "pending@amazon.com"
      spree_address = Spree::Address.new(
        firstname: "Amazon",
        lastname: "User",
        address1: "TBD",
        phone: "TBD",
        city: address.city,
        zipcode: address.zipcode,
        state_name: address.state_name,
        country: address.country
      )
      spree_address.save!
      current_order.ship_address_id = spree_address.id
      current_order.bill_address_id = spree_address.id
      current_order.save!
      current_order.next! # to Address
      current_order.next! # to Delivery

      current_order.reload
      render :layout => false
    else
      redirect_to address_amazon_order_path, :notice => "Unable to load Address data from Amazon"
    end
  end

  def confirm
    if current_order.update_from_params(params, permitted_checkout_attributes, request.headers.env)
      order = SpreeAmazon::Order.new(
        reference_id: current_order.amazon_order_reference_id,
        total: current_order.total,
        currency: current_order.currency
      )
      order.save_total
      order.confirm
      order.fetch

      if order.address
        current_order.email = order.email
        current_order.save!

        address = order.address
        new_shipping_address = current_order.ship_address.dup
        new_shipping_address.update(
          firstname: address.first_name,
          lastname: address.last_name,
          address1: address.address1,
          phone: address.phone || "N/A",
          city: address.city,
          zipcode: address.zipcode,
          state_name: address.state_name,
          country: address.country
        )

        if current_order.ship_address != new_shipping_address
          ActiveRecord::Base.transaction do
            old_shipping_address = current_order.ship_address
            current_order.ship_address = new_shipping_address
            current_order.save!
          end
        end
      else
        raise "There is a problem with your order"
      end
      current_order.create_tax_charge!
      current_order.reload
      payment = current_order.payments.valid.amazon.first
      payment.amount = current_order.total
      payment.save!
      @order = current_order

      # Remove the following line to enable the confirmation step.
      # redirect_to amazon_order_complete_path(@order)
    else
      render :edit
    end
  end

  def complete
    @order = Spree::Order.find_by(:number => params[:amazon_order_id])
    authorize!(:edit, @order, cookies.signed[:guest_token])

    redirect_to root_path if @order.nil?
    while(@order.next) do

    end

    if @order.completed?
      @current_order = nil
      flash.notice = Spree.t(:order_processed_successfully)
      redirect_to spree.order_path(@order)
    else
      @order.state = 'cart'
      @order.amazon_transactions.destroy_all
      redirect_to cart_path, :notice => "Unable to process order"
      return true
    end
  end

  private

  def check_current_order
    unless current_order
      redirect_to root_path, :notice => "No Order Found"
    end
  end

  def check_amazon_reference_id
    unless current_order.amazon_order_reference_id
      redirect_to root_path, notice: 'No order reference found'
    end
  end
end

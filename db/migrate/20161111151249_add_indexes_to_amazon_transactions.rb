class AddIndexesToAmazonTransactions < ActiveRecord::Migration
  def change
    add_index 'spree_amazon_transactions', 'order_id'
    add_index 'spree_amazon_transactions', 'order_reference'
  end
end

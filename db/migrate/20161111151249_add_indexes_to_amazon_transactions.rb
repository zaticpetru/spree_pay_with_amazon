class AddIndexesToAmazonTransactions < ActiveRecord::Migration[4.2]
  def change
    add_index 'spree_amazon_transactions', 'order_id'
    add_index 'spree_amazon_transactions', 'order_reference'
  end
end

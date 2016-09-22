class AddClosedAtToSpreeAmazonTransaction < ActiveRecord::Migration
  def change
    add_column :spree_amazon_transactions, :closed_at, :datetime
  end
end
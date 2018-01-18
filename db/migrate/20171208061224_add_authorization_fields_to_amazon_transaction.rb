class AddAuthorizationFieldsToAmazonTransaction < ActiveRecord::Migration
  def change
    add_column :spree_amazon_transactions, :success, :boolean
    add_column :spree_amazon_transactions, :message, :string
    add_column :spree_amazon_transactions, :soft_decline, :boolean, default: true
    add_column :spree_amazon_transactions, :authorization_reference_id, :string
    add_column :spree_amazon_transactions, :retry, :boolean, default: false
  end
end

require 'spec_helper'

describe Spree::Admin::AmazonController do
  let(:user) { create(:user) }

  before do
    allow(controller).to receive_messages :spree_current_user => user
    user.spree_roles << Spree::Role.find_or_create_by(name: 'admin')
  end

  describe 'PUT #update' do
    it "updates the amazon payments configuration" do
      settings = {
        utf8: '✓',
        client_id: 'CLIENT_ID',
        merchant_id: 'MERCHANT_ID',
        aws_access_key_id: 'AWS_KEY_ID',
        aws_secret_access_key: 'AWS_SECRET_KEY_ID'
      }

      spree_put :update, settings

      expect(SpreeAmazon::Config[:client_id]).to eq('CLIENT_ID')
      expect(SpreeAmazon::Config[:merchant_id]).to eq('MERCHANT_ID')
      expect(SpreeAmazon::Config[:aws_access_key_id]).to eq('AWS_KEY_ID')
      expect(SpreeAmazon::Config[:aws_secret_access_key]).to eq('AWS_SECRET_KEY_ID')
    end

    it "sets a flash message" do
      settings = {}

      spree_put :update, settings

      expect(flash[:success]).to eq("Amazon Settings has been successfully updated!")
    end
  end
end

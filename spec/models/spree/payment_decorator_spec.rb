require 'spec_helper'

describe Spree::Payment, type: :model do
  describe '#amazon' do
    it 'returns all amazon payments' do
       payment = create(:amazon_payment)

      expect(Spree::Payment.amazon).to include(payment)
     end

    it 'does not include non amazon payments' do
       payment = create(:payment)

      expect(Spree::Payment.amazon).to_not include(payment)
     end
   end

  context "processing" do

    let(:order) { Spree::Order.create }

    let(:payment) { create(:amazon_payment) }
    let(:payment_source) { payment.source }
    let(:gateway) { payment.payment_method }

    let(:amount_in_cents) { (payment.amount * 100).round }

    let!(:success_response) do
      ActiveMerchant::Billing::Response.new(true, '', {}, {
        authorization: '123',
        cvv_result: nil,
        avs_result: { code: nil }
        })
    end

    before(:each) do
    # So it doesn't create log entries every time a processing method is called
      allow(payment.log_entries).to receive(:create!)
    end

    describe "#process!" do
      describe "#authorize!" do
        context "if successful" do
          before do
            expect(payment.payment_method).to receive(:authorize).with(amount_in_cents,
             payment_source,
             anything).and_return(success_response)
          end

          it "should store the response_code" do
            payment.authorize!
            expect(payment.response_code).to eq('123')
          end
        end

        describe "#purchase!" do
          context "if successful" do
            before do
              expect(payment.payment_method).to receive(:purchase).with(amount_in_cents,
                payment_source,
                anything).and_return(success_response)
            end

            it "should store the response_code" do
              payment.purchase!
              expect(payment.response_code).to eq('123')
            end
          end
        end

        describe "#capture!" do
          context "when payment is pending" do
            before do
              payment.amount = 100
              payment.state = 'pending'
              payment.response_code = '12345'
            end

            context "if successful" do
              context 'for entire amount' do
                before do
                  expect(payment.payment_method).to receive(:capture).with(payment.display_amount.money.cents, payment.response_code, anything).and_return(success_response)
                end

                it "should store the response_code" do
                  payment.capture!
                  expect(payment.response_code).to eq('123')
                end
              end
            end
          end
        end
      end

      describe "#cancel!" do
        before do
          payment.response_code = 'abc'
          payment.state = 'pending'
        end

        context "if successful" do
          it "should update the response_code with the authorization from the gateway" do
            allow(gateway).to receive_messages :cancel => success_response
            payment.cancel!
            expect(payment.state).to eq('void')
            expect(payment.response_code).to eq('123')
          end
        end
      end


      describe "#void_transaction!" do
        before do
          payment.response_code = '123'
          payment.state = 'pending'
        end

        context "if successful" do
          it "should update the response_code with the authorization from the gateway" do
            allow(gateway).to receive_messages :void => success_response
            payment.void_transaction!
            expect(payment.response_code).to eq('123')
          end
        end
      end
    end
  end
end
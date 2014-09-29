require 'spec_helper'

describe Billing::Invoice do
  let(:account) { create(:account_active) }
  let(:subscription) { account.subscription }
  let(:plan) { subscription.plan }

  describe '#accept_payment' do
    context 'when partly paid' do
      let(:invoice) { create(:billing_invoice, account: account, amount: 1000 ) }
      let(:payment) { create(:billing_payment, amount: 500)}

      it { expect { invoice.accept_payment(payment) }.to change(invoice, :state).to("partly_paid") }
      it { expect { invoice.accept_payment(payment) }.to change(account.payments, :count).by(1) }
      it { expect { invoice.accept_payment(payment) }.to change(payment, :state).to("accepted") }

      it {
        invoice.stub(:add_funds_to_account).and_return(true)
        invoice.should_not_receive(:add_funds_to_account)
        invoice.accept_payment(payment)
      }
    end

    context 'when fully paid' do
      let(:invoice) { create(:billing_invoice, account: account, amount: 1000 ) }
      let(:payment) { create(:billing_payment, amount: 1000)}

      it { expect { invoice.accept_payment(payment) }.to change(invoice, :state).to("paid") }
      it { expect { invoice.accept_payment(payment) }.to change(account.payments, :count).by(1) }
      it { expect { invoice.accept_payment(payment) }.to change(payment, :state).to("accepted") }
      it {
        expected_change = plan.coins
        expect { invoice.accept_payment(payment) }.to change(account, :balance).by(expected_change)
      }
    end

    context 'when invoice already paid' do
      let!(:invoice) { create(:billing_invoice, account: account, amount: 1000, state: :paid) }
      let!(:payment) { create(:billing_payment_manual_accepted, amount: 1000, invoice: invoice) }
      it {
        invoice.stub(:add_funds_to_account).and_return('true')
        invoice.should_not_receive(:add_funds_to_account)
        invoice.accept_payment(payment)
      }
    end

  end

  describe '#fully_paid?' do
    let(:payments) { create_list(:billing_payment, 3, state: "accepted", account: account)}
    let(:payments_amount) { payments.map(&:amount).sum }
    before { payments.each{|payment| invoice.accept_payment(payment)} }

    context "when fully paid" do
      let(:invoice)  { create(:billing_invoice, account: account, amount: payments_amount) }
      it { expect(invoice).to be_fully_paid }
    end

    context "when partly paid" do
      let(:invoice)  { create(:billing_invoice, account: account, amount: payments_amount + 1000) }
      it { expect(invoice).to_not be_fully_paid }
    end
  end

end

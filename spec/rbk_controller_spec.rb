require 'spec_helper'

describe Dashboard::Billing::RbkController do

  render_views

  let!(:user) { create(:user_with_filled_company) }
  let!(:account) { user.account }

  describe 'GET rbk_success' do
    before { get :rbk_success }
    it { should redirect_to(dashboard_billing_invoices_path) }
    it { flash[:success].should == I18n.t('dashboard.billing.invoices.controller.success_payment') }
  end

  describe 'GET rbk_fail' do
    before { get :rbk_fail }
    it { should redirect_to(dashboard_billing_invoices_path) }
    it { flash[:error].should == I18n.t('dashboard.billing.invoices.controller.fail_payment') }
  end

  describe 'POST rbk_confirm' do
    let(:invoice) { create(:billing_subscription_invoice, account: account) }
    let(:payment_status) { '3' }
    let(:rbk_params) { build(:rbk_params, invoice: invoice, paymentStatus: payment_status) }

    it { expect { post :rbk_confirm, rbk_params }.to change(invoice.payments, :count).by(1) }

    context 'without params' do
      before { post :rbk_confirm }

      it { expect(response.response_code).to eq(500)  }
      it { expect(response.body).to eq('Incorrect signature') }
    end

    context 'with incorrect checksum' do
      let(:rbk_params) { build(:rbk_params_incorrect, invoice: invoice) }

      before { post :rbk_confirm, rbk_params }
      before { invoice.reload }

      it { expect(response.response_code).to eq(500)  }
      it { expect(response.body).to eq('Incorrect signature') }
      it { expect(invoice).to be_pending }
    end

    context 'when payment pending' do
      let(:payment) { invoice.payments.first }

      before { post :rbk_confirm, rbk_params }
      before { invoice.reload }

      it { expect(response.response_code).to eq(200)  }
      it { expect(payment).to be_received }
    end

    context 'when payment confirmed' do
      let(:payment) { invoice.payments.first }
      let(:payment_status) { '5' }

      before { post :rbk_confirm, rbk_params }
      before { invoice.reload }

      it { expect(response.response_code).to eq(200)  }
      it { expect(invoice).to be_paid }
      it { expect(payment).to be_accepted }
    end

    context 'when recurring payment not exists' do
      context 'and paymentStatus pending' do
        let(:rbk_params) { build(:rbk_params_recurring, invoice: invoice, paymentStatus: '3') }

        it { expect { post :rbk_confirm, rbk_params }.not_to change(Billing::RecurringPayment, :count) }
      end

      context 'and paymentStatus complete' do
        let(:rbk_params) { build(:rbk_params_recurring, invoice: invoice) }

        it { expect { post :rbk_confirm, rbk_params }.to change(Billing::RecurringPayment, :count).by(1) }
      end
    end

  end

end

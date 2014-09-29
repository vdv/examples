#encoding: utf-8
class Dashboard::Billing::RbkController < Dashboard::Billing::BaseController

  skip_before_filter :verify_authenticity_token,  only: [:rbk_success, :rbk_confirm, :rbk_fail]
  skip_before_filter :authenticate_user!,         only: [:rbk_success, :rbk_confirm, :rbk_fail]

  before_filter :rbk_notification, :rbk_find_invoice, only: [:rbk_confirm]

  def rbk_confirm
    account             = @invoice.account
    pay_sum             = @notification.params['rupay_payment_sum']
    recuring_payment_id = @notification.params['recurringpaymentid']
    payment_id          = @notification.transaction_id

    payment = ::Billing::Payment.find_or_initialize_by(transaction_id: @notification.transaction_id)
    payment.update_attributes invoice: @invoice,
                              account: account,
                              amount: pay_sum,
                              comment: @invoice.comment,
                              payment_method: 'rbkmoney',
                              transaction_id: @notification.transaction_id,
                              transaction_params: @notification.params

    if @notification.complete?
      @invoice.accept_payment(payment)

      account.enable_recurring_payments payment_id, recuring_payment_id if recuring_payment_id
    elsif @notification.status == 'pending'
      payment.receive
    end

    render status: 200, text: 'OK'
  end

  # rbk redirect here on success payment
  def rbk_success
    instrument('on_success.rbk_payment', params: params)

    flash[:success] = I18n.t('dashboard.billing.invoices.controller.success_payment')
    redirect_to dashboard_billing_invoices_url
  end

  # rbk redirect here on fail payment
  def rbk_fail
    instrument('on_fail.rbk_payment', params: params)

    flash[:error] = I18n.t('dashboard.billing.invoices.controller.fail_payment')
    redirect_to dashboard_billing_invoices_url
  end

  protected

    def rbk_notification
      @notification = ActiveMerchant::Billing::Integrations::Rbkmoney::Notification.new(request.raw_post, :secret => Settings.rbkmoney.secret)

      instrument('incoming_request.rbk_payment', request: request, notification: @notification)

      unless @notification.acknowledge
        instrument('invalid_request.rbk_payment', params: params)
        render status: 500, text: 'Incorrect signature' and return
        return
      end
    end

    def rbk_find_invoice
      @invoice = ::Billing::Invoice.find_by(id: @notification.item_id)

      if @invoice.nil?
        instrument('invoice_not_found.rbk_payment')
        render status: 500, text: 'Invoice not found' and return
      end

      instrument('found_invoice.rbk_payment', invoice: @invoice)

      if @invoice.paid?
        @invoice = @invoice.account.wait_payments_invoice || @invoice
        instrument('found_unpaid_invoice.rbk_payment', invoice: @invoice)
      end
    end

end

class Billing::Invoice

  include Mongoid::Document
  include Mongoid::Timestamps

  PAYMENT_METHODS = %w/recurring rbkmoney/

  belongs_to :account
  has_many   :payments, class_name: 'Billing::Payment'

  field :amount,         type: Integer
  field :comment,        type: String
  field :payment_method, type: String, default: 'recurring'

  validates :account, presence: true

  scope :wait_payments,        where(:state.in => ['pending', 'confirmed', 'partly_pay'])
  scope :pending_or_confirmed, where(:state.in => ['pending', 'confirmed'])
  scope :not_paid,             where(:state.ne => 'paid')

  state_machine :state, :initial => :pending do
    event :confirm do
      transition any => :confirmed
    end

    event :partly_pay do
      transition [:pending, :confirmed] => :partly_paid
    end

    event :pay do
      transition any - [ :paid ] => :paid
    end

    event :cancel do
      transition any - [ :paid ] => :canceled
    end
  end

  def accept_payment(payment)
    payments << payment unless payment.in? payments
    payment.accept

    if fully_paid?
      pay and add_funds_to_account
    else
      partly_pay
    end
  end

  def fully_paid?
    accepted_payments_sum >= amount
  end

  def received_payments?
    payments.received.any?
  end

  def amount_to_pay
    amount - accepted_payments_sum
  end

  def accepted_payments_sum
    payments.accepted.sum(:amount)
  end

  private

    def add_funds_to_account
      account.deposit_balance(coins_to_deposit)
    end

    def coins_to_deposit
      plan = account.subscription.plan
      plan.coins
    end

end

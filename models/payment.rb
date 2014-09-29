class Billing::Payment

  include Mongoid::Document
  include Mongoid::Timestamps

  PAYMENT_METHODS = %w/rbkmoney manual/

  belongs_to :account
  belongs_to :invoice, class_name: 'Billing::Invoice'

  field :amount,  type: Integer
  field :comment, type: String
  field :payment_method, type: String

  field :transaction_id, type: String
  field :transaction_params, type: Hash

  index(account_id: 1)

  validates :account, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :payment_method, inclusion: { in: PAYMENT_METHODS }

  before_validation do |record|
    record.account = record.invoice.account if record.invoice
  end

  scope :accepted, -> { where(state: 'accepted') }
  scope :received, -> { where(state: 'received') }

  state_machine :state, :initial => :pending do
    event :receive do
      transition :pending => :received
    end

    event :accept do
      transition any => :accepted
    end

    state :accepted  do
      validates_presence_of :invoice
    end
  end

end

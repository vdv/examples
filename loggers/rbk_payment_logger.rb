class RbkPaymentLogger < ActiveSupport::LogSubscriber

  self.logger = Logger.new("log/payments_#{Rails.env}.log", 'monthly')
  self.logger.datetime_format = "%Y-%m-%d %H:%M:%S"
  self.logger.formatter = proc do |severity, datetime, progname, msg|
    "[#{severity}][#{datetime}]: #{msg}\n"
  end

  # payload: params
  def on_success(event)
    payload = event.payload

    info("RBK success with params #{payload[:params].inspect}")
  end

  # # payload: params
  def on_fail(event)
    payload = event.payload

    error("RBK fail with params #{payload[:params].inspect}")
  end

  # payload: request, notification
  def incoming_request(event)
    payload = event.payload

    info <<-STR.strip_heredoc
    RBK Incoming request
      raw post: #{payload[:request].raw_post}
      parsed params: #{payload[:notification].params.inspect}
    STR
  end

  # payload: params
  def invalid_request(event)
    error("RBK Invalid Request")
  end

  def invoice_not_found(event)
    error("RBK Invoice not found")
  end

  # payload: invoice
  def found_invoice(event)
    payload = event.payload

    info("RBK found invoice: #{payload[:invoice].inspect}")
  end

  # payload: invoice
  def found_unpaid_invoice(event)
    payload = event.payload

    info("RBK found unpaid invoice: #{payload[:invoice].inspect}")
  end
end

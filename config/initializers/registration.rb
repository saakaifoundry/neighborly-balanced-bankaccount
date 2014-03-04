review_path = ->(contribution) do
  Neighborly::Balanced::Bankaccount::Engine.
    routes.url_helpers.new_payment_path(contribution_id: contribution)
end

value_with_fees = ->(value) do
  "TODO"
end

begin
  PaymentEngines.register(name:           'balanced-bankaccount',
                          locale:         'en',
                          value_with_fees: value_with_fees,
                          review_path:    review_path)
rescue Exception => e
  puts "Error while registering payment engine: #{e}"
end
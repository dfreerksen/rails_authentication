# frozen_string_literal: true

module RequestHelpers
  PASSWORD = "password123"

  def create_user(email: "user@example.com", confirmed: true, **attrs)
    User.create!(
      email_address: email,
      password: PASSWORD,
      password_confirmation: PASSWORD,
      confirmed_at: confirmed ? Time.current : nil,
      **attrs
    )
  end

  def sign_in(user, password: PASSWORD, remember: false)
    params = { email_address: user.email_address, password: password }
    params[:remember_me] = "1" if remember
    post "/session", params: params
  end

  def sign_out
    delete "/session"
  end

  def last_email
    ActionMailer::Base.deliveries.last
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Password reset (recoverable)", type: :request do
  it "resets the password with an emailed DB-backed token" do
    user = create_user

    post "/passwords", params: { email_address: user.email_address }
    expect(response).to redirect_to("/session/new")

    token = user.reload.reset_password_token
    expect(token).to be_present
    expect(last_email.to).to eq([user.email_address])
    expect(last_email.subject).to eq("Reset your password")
    expect(last_email.text_part.body.to_s).to include(token)

    patch "/passwords/#{token}", params: { password: "newpassword456", password_confirmation: "newpassword456" }
    expect(response).to redirect_to("/session/new")
    expect(user.reload.reset_password_token).to be_nil

    sign_in user, password: "newpassword456"
    expect(response).to redirect_to("http://www.example.com/")
  end

  it "invalidates existing sessions when the password is reset" do
    user = create_user
    sign_in user
    get "/"
    expect(response).to have_http_status(:ok)

    user.generate_reset_password_token!
    patch "/passwords/#{user.reload.reset_password_token}",
      params: { password: "newpassword456", password_confirmation: "newpassword456" }

    get "/"
    expect(response).to redirect_to("/session/new")
  end

  it "rejects expired reset tokens" do
    user = create_user
    user.generate_reset_password_token!
    token = user.reload.reset_password_token

    travel 5.hours do
      patch "/passwords/#{token}", params: { password: "newpassword456", password_confirmation: "newpassword456" }

      expect(response).to redirect_to("/passwords/new")
      expect(user.reload.authenticate("newpassword456")).to be false
    end
  end

  it "does not reveal whether an email address exists" do
    post "/passwords", params: { email_address: "nobody@example.com" }

    expect(response).to redirect_to("/session/new")
    expect(ActionMailer::Base.deliveries).to be_empty
  end
end

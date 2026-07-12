# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Confirmation", type: :request do
  it "blocks sign-in until the email address is confirmed" do
    user = create_user(confirmed: false)
    user.generate_confirmation_token!

    sign_in user
    expect(response).to redirect_to("/session/new")
    follow_redirect!
    expect(response.body).to include("You must confirm your email address")

    get "/confirmations/#{user.reload.confirmation_token}"
    expect(response).to redirect_to("/session/new")
    expect(user.reload).to be_confirmed
    expect(user.confirmation_token).to be_nil

    sign_in user
    expect(response).to redirect_to("http://www.example.com/")
  end

  it "rejects expired confirmation tokens" do
    user = create_user(confirmed: false)
    user.generate_confirmation_token!
    token = user.reload.confirmation_token

    travel 25.hours do
      get "/confirmations/#{token}"

      expect(response).to redirect_to("/confirmations/new")
      expect(user.reload).not_to be_confirmed
    end
  end

  it "resends confirmation instructions to unconfirmed users only" do
    unconfirmed = create_user(email: "unconfirmed@example.com", confirmed: false)

    post "/confirmations", params: { email_address: unconfirmed.email_address }
    expect(last_email.to).to eq(["unconfirmed@example.com"])
    expect(unconfirmed.reload.confirmation_token).to be_present

    ActionMailer::Base.deliveries.clear
    confirmed = create_user(email: "confirmed@example.com")
    post "/confirmations", params: { email_address: confirmed.email_address }
    expect(ActionMailer::Base.deliveries).to be_empty
  end
end

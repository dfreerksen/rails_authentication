# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ott", type: :request do
  it "signs in via an emailed 6-digit code, which is single-use" do
    user = create_user

    post "/ott", params: { email_address: user.email_address }
    expect(response).to redirect_to("/ott/edit")
    expect(last_email.to).to eq([user.email_address])

    code = user.reload.ott_code
    expect(code).to match(/\A\d{6}\z/)
    expect(last_email.body.encoded).to include(code)

    get "/ott/edit"
    expect(response.body).to include("Enter your sign-in code")

    patch "/ott", params: { code: code }
    expect(response).to redirect_to("http://www.example.com/")
    expect(user.reload.ott_code).to be_nil

    follow_redirect!
    expect(response.body).to include("Home")
  end

  it "does not email unknown addresses but shows the same notice" do
    post "/ott", params: { email_address: "nobody@example.com" }

    expect(response).to redirect_to("/ott/edit")
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "resends a fresh code without re-entering the email address" do
    user = create_user
    post "/ott", params: { email_address: user.email_address }
    first_code = user.reload.ott_code

    post "/ott"

    expect(response).to redirect_to("/ott/edit")
    expect(ActionMailer::Base.deliveries.size).to eq(2)
    expect(user.reload.ott_code).not_to eq(first_code)
  end

  it "redirects to sign-in when there is no pending code" do
    get "/ott/edit"

    expect(response).to redirect_to("/session/new")
  end

  it "rejects wrong codes and voids the code after 5 attempts" do
    user = create_user
    post "/ott", params: { email_address: user.email_address }
    code = user.reload.ott_code

    4.times do
      patch "/ott", params: { code: "000000" == code ? "111111" : "000000" }
      expect(response).to redirect_to("/ott/edit")
    end
    expect(user.reload.ott_code).to be_present

    patch "/ott", params: { code: "000000" == code ? "111111" : "000000" }
    expect(response).to redirect_to("/session/new")
    expect(user.reload.ott_code).to be_nil

    # The real code no longer works either.
    patch "/ott", params: { code: code }
    expect(response).to redirect_to("/session/new")
  end

  it "rejects expired codes" do
    user = create_user
    post "/ott", params: { email_address: user.email_address }
    code = user.reload.ott_code

    travel 11.minutes do
      patch "/ott", params: { code: code }

      expect(response).to redirect_to("/session/new")
      follow_redirect!
      expect(response.body).to include("invalid or has expired")
    end
  end

  it "blocks unconfirmed users without consuming the code" do
    user = create_user(confirmed: false)
    post "/ott", params: { email_address: user.email_address }
    code = user.reload.ott_code

    patch "/ott", params: { code: code }

    expect(response).to redirect_to("/session/new")
    follow_redirect!
    expect(response.body).to include("You must confirm your email address")
    expect(user.reload.ott_code).to be_present
  end

  it "blocks locked users" do
    user = create_user
    post "/ott", params: { email_address: user.email_address }
    user.lock!
    code = user.reload.ott_code

    patch "/ott", params: { code: code }

    expect(response).to redirect_to("/session/new")
    follow_redirect!
    expect(response.body).to include("Your account is locked")
  end

  it "keeps password sign-in functional even though the form is replaced" do
    user = create_user

    sign_in user

    expect(response).to redirect_to("http://www.example.com/")
  end

  it "offers a runtime toggle between the code form and the password form" do
    get "/session/new"
    expect(response.body).to include("Email me a sign-in code")
    expect(response.body).not_to include('type="password"')
    expect(response.body).to include("Sign in with password instead")

    get "/session/new", params: { with_password: 1 }
    expect(response.body).to include('type="password"')
    expect(response.body).to include("Sign in with a one-time code instead")
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MagicLink", type: :request do
  it "signs in via an emailed magic link, which is single-use" do
    user = create_user

    post "/magic_links", params: { email_address: user.email_address }
    expect(response).to redirect_to("/session/new")
    expect(last_email.to).to eq([user.email_address])

    token = user.reload.magic_link_token
    expect(token).to be_present
    expect(last_email.body.encoded).to include(token)

    get "/magic_links/#{token}"
    expect(response).to redirect_to("http://www.example.com/")
    expect(user.reload.magic_link_token).to be_nil

    follow_redirect!
    expect(response.body).to include("Home")

    sign_out
    get "/magic_links/#{token}"
    expect(response).to redirect_to("/magic_links/new")
  end

  it "does not email unknown addresses but shows the same notice" do
    post "/magic_links", params: { email_address: "nobody@example.com" }

    expect(response).to redirect_to("/session/new")
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "rejects expired magic links" do
    user = create_user
    user.generate_magic_link_token!
    token = user.reload.magic_link_token

    travel 21.minutes do
      get "/magic_links/#{token}"

      expect(response).to redirect_to("/magic_links/new")
      expect(user.reload.magic_link_token).to be_present
    end
  end

  it "blocks unconfirmed users without consuming the token" do
    user = create_user(confirmed: false)
    user.generate_magic_link_token!

    get "/magic_links/#{user.reload.magic_link_token}"

    expect(response).to redirect_to("/session/new")
    follow_redirect!
    expect(response.body).to include("You must confirm your email address")
    expect(user.reload.magic_link_token).to be_present
  end

  it "blocks locked users" do
    user = create_user
    user.lock!
    user.generate_magic_link_token!

    get "/magic_links/#{user.reload.magic_link_token}"

    expect(response).to redirect_to("/session/new")
    follow_redirect!
    expect(response.body).to include("Your account is locked")
  end
end

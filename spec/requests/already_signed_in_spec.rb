# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Signed-out flows while already signed in" do
  before { sign_in create_user }

  {
    "sign-in form" => "/session/new",
    "sign-up form" => "/registration/new",
    "password reset request" => "/passwords/new",
    "password reset link" => "/passwords/some-token/edit",
    "confirmation resend form" => "/confirmations/new",
    "unlock request form" => "/unlocks/new",
    "unlock link" => "/unlocks/some-token",
    "magic link request form" => "/magic_links/new",
    "magic link" => "/magic_links/some-token",
    "one-time code form" => "/ott/edit",
    "invitation acceptance" => "/invitations/some-token/edit"
  }.each do |description, path|
    it "redirects the #{description} to root" do
      get path

      expect(response).to redirect_to("/")
      expect(flash[:alert]).to eq("You are already signed in.")
    end
  end

  it "redirects a second sign-in attempt without creating another session" do
    user = User.sole

    expect do
      post "/session", params: { email: user.email, password: RequestHelpers::PASSWORD }
    end.not_to change(Session, :count)

    expect(response).to redirect_to("/")
  end

  it "rejects passkey sign-in with a JSON error" do
    post "/passkey_session", as: :json

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body).to eq("error" => "You are already signed in.")
  end

  it "still lets the emailed confirmation link through (reconfirmable email changes)" do
    get "/confirmations/some-token"

    expect(response).to redirect_to("/confirmations/new")
  end
end

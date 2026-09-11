# frozen_string_literal: true

require "rails_helper"
require "webauthn/fake_client"

RSpec.describe "Passkey", type: :request do
  let(:fake_client) { WebAuthn::FakeClient.new("http://www.example.com") }

  around do |example|
    original_allowed_origins = WebAuthn.configuration.allowed_origins
    WebAuthn.configuration.allowed_origins = ["http://www.example.com"]
    example.run
    WebAuthn.configuration.allowed_origins = original_allowed_origins
  end

  def register_passkey_for(user)
    sign_in(user)

    get "/webauthn_credentials/new"
    options = extract_webauthn_options(response.body, "@webauthn_credential_options")

    create_result = fake_client.create(challenge: options["challenge"])

    post "/webauthn_credentials",
      params: create_result.merge(nickname: "Test device").to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:success)
    sign_out
  end

  def extract_webauthn_options(body, _var_name)
    json = body[/const options = (\{.*?\});/m, 1]
    JSON.parse(json)
  end

  it "registers a passkey and signs in with it, without a password" do
    user = create_user
    register_passkey_for(user)
    expect(user.webauthn_credentials.count).to eq(1)

    get "/session/new"
    options = extract_webauthn_options(response.body, "@webauthn_credential_options")

    get_result = fake_client.get(challenge: options["challenge"])

    post "/passkey_session",
      params: get_result.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:success)
    json = JSON.parse(response.body)
    expect(json["redirect_to"]).to be_present

    follow_redirect_to json["redirect_to"]
    expect(response.body).to include("Home")
  end

  it "rejects an unrecognized passkey" do
    other_client = WebAuthn::FakeClient.new("http://www.example.com")
    # Give the fake authenticator a credential to sign with — it's never registered with
    # our server (via POST /webauthn_credentials), which is exactly what makes the
    # resulting assertion unrecognized below.
    other_client.create(challenge: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false))

    get "/session/new"
    options = extract_webauthn_options(response.body, "@webauthn_credential_options")

    get_result = other_client.get(challenge: options["challenge"])

    post "/passkey_session",
      params: get_result.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)["error"]).to eq("Passkey not recognized.")
  end

  it "blocks locked users" do
    user = create_user
    register_passkey_for(user)
    user.lock!

    get "/session/new"
    options = extract_webauthn_options(response.body, "@webauthn_credential_options")
    get_result = fake_client.get(challenge: options["challenge"])

    post "/passkey_session",
      params: get_result.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)["error"]).to include("locked")
  end

  private

  def follow_redirect_to(path)
    get path
  end
end

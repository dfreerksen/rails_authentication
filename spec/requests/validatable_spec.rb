# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Validations (validatable)", type: :request do
  it "rejects malformed email addresses" do
    expect {
      post "/registration", params: { email_address: "not-an-email", password: "password123", password_confirmation: "password123" }
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Email address is invalid")
  end

  it "rejects passwords shorter than 6 characters" do
    expect {
      post "/registration", params: { email_address: "new@example.com", password: "short", password_confirmation: "short" }
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Password is too short")
  end

  it "rejects passwords that only satisfy one complexity rule" do
    expect {
      post "/registration", params: { email_address: "new@example.com", password: "alllowercase", password_confirmation: "alllowercase" }
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Password must meet password complexity standards")
  end

  it "accepts passwords that satisfy two complexity rules" do
    expect {
      post "/registration", params: { email_address: "new@example.com", password: "password123", password_confirmation: "password123" }
    }.to change(User, :count).by(1)

    expect(response).to have_http_status(:redirect)
  end

  it "accepts passwords that satisfy all complexity rules" do
    expect {
      post "/registration", params: { email_address: "another@example.com", password: "Password123!", password_confirmation: "Password123!" }
    }.to change(User, :count).by(1)

    expect(response).to have_http_status(:redirect)
  end

  it "rejects duplicate email addresses case-insensitively" do
    create_user(email: "taken@example.com")

    expect {
      post "/registration", params: { email_address: "TAKEN@example.com", password: "password123", password_confirmation: "password123" }
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Validations (validatable)" do
  it "rejects malformed email addresses" do
    expect do
      post "/registration",
           params: { email: "not-an-email", password: "password123", password_confirmation: "password123" }
    end.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Email is invalid")
  end

  it "rejects passwords shorter than 6 characters" do
    expect do
      post "/registration",
           params: { email: "new@example.com", password: "short", password_confirmation: "short" }
    end.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Password is too short")
  end

  it "rejects passwords that only satisfy one complexity rule" do
    expect do
      post "/registration",
           params: { email: "new@example.com", password: "alllowercase", password_confirmation: "alllowercase" }
    end.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Password must meet password complexity standards")
  end

  it "accepts passwords that satisfy two complexity rules" do
    expect do
      post "/registration",
           params: { email: "new@example.com", password: "password123", password_confirmation: "password123" }
    end.to change(User, :count).by(1)

    expect(response).to have_http_status(:redirect)
  end

  it "accepts passwords that satisfy all complexity rules" do
    expect do
      post "/registration",
           params: { email: "another@example.com", password: "Password123!",
                     password_confirmation: "Password123!" }
    end.to change(User, :count).by(1)

    expect(response).to have_http_status(:redirect)
  end

  it "rejects duplicate email addresses case-insensitively" do
    create_user(email: "taken@example.com")

    expect do
      post "/registration",
           params: { email: "TAKEN@example.com", password: "password123", password_confirmation: "password123" }
    end.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Registration", type: :request do
  it "signs up a new user and sends confirmation instructions" do
    expect {
      post "/registration", params: {
        email_address: "new@example.com", password: RequestHelpers::PASSWORD, password_confirmation: RequestHelpers::PASSWORD
      }
    }.to change(User, :count).by(1)

    expect(response).to redirect_to("/session/new")

    user = User.find_by!(email_address: "new@example.com")
    expect(user).not_to be_confirmed
    expect(user.confirmation_token).to be_present
    expect(last_email.to).to eq(["new@example.com"])
    expect(last_email.subject).to eq("Confirm your email address")
  end

  it "re-renders the form when the user is invalid" do
    expect {
      post "/registration", params: {
        email_address: "new@example.com", password: RequestHelpers::PASSWORD, password_confirmation: "different"
      }
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "updates the account, keeping the password when it is left blank" do
    user = create_user
    sign_in user

    patch "/registration", params: { email_address: "renamed@example.com", password: "", password_confirmation: "" }

    expect(response).to redirect_to("/registration/edit")
    expect(user.reload.email_address).to eq("renamed@example.com")
    expect(user.authenticate(RequestHelpers::PASSWORD)).to be_truthy
  end

  it "deletes the account" do
    user = create_user
    sign_in user

    expect { delete "/registration" }.to change(User, :count).by(-1)
    expect(response).to redirect_to("/session/new")
  end

  it "requires authentication for account editing" do
    get "/registration/edit"

    expect(response).to redirect_to("/session/new")
  end
end

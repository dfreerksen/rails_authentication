# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Password reset (recoverable)" do
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

  # Password reset is a signed-out flow (a signed-in browser is redirected away from it; see
  # already_signed_in_spec.rb), so the devices that sign in are separate sessions and the reset
  # happens in this test's own browser, which stays signed out.
  it "invalidates existing sessions when the password is reset" do
    user = create_user
    device = signed_in_device(user)
    expect(device.get("/")).to eq(200)

    reset_password(user)

    expect(user.sessions.count).to eq(0)
    expect(device.get("/")).to eq(302)
  end

  it "invalidates sessions on every device, remembered or not, when the password is reset" do
    user = create_user
    remembered_device = signed_in_device(user, remember: true)
    other_device = signed_in_device(user)
    expect(user.sessions.count).to eq(2)
    expect(user.sessions.select(&:remembered?).size).to eq(1)

    reset_password(user)

    expect(user.sessions.count).to eq(0)
    expect(remembered_device.get("/")).to eq(302)
    expect(other_device.get("/")).to eq(302)
  end

  it "rejects a blank new password, leaving the token, sessions, and password unchanged" do
    user = create_user
    signed_in_device(user)
    user.generate_reset_password_token!
    token = user.reload.reset_password_token

    patch "/passwords/#{token}", params: { password: "", password_confirmation: "" }

    expect(response).to redirect_to("/passwords/#{token}/edit")
    expect(flash[:alert]).to eq("Enter a new password.")
    expect(user.reload.reset_password_token).to eq(token)
    expect(user.sessions.count).to eq(1)
    expect(user.authenticate(RequestHelpers::PASSWORD)).to be_truthy
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

  def signed_in_device(user, remember: false)
    params = { email_address: user.email_address, password: RequestHelpers::PASSWORD }
    params[:remember_me] = "1" if remember
    open_session.tap { |device| device.post "/session", params: params }
  end

  def reset_password(user)
    user.generate_reset_password_token!
    patch "/passwords/#{user.reload.reset_password_token}",
          params: { password: "newpassword456", password_confirmation: "newpassword456" }
    expect(response).to redirect_to("/session/new")
  end
end

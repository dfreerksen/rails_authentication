# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Account locking (lockable)", type: :request do
  it "locks the account after 5 failed attempts and emails unlock instructions" do
    user = create_user

    4.times { sign_in user, password: "wrong" }
    expect(user.reload).not_to be_locked

    sign_in user, password: "wrong"

    user.reload
    expect(user).to be_locked
    expect(user.unlock_token).to be_present
    expect(last_email.to).to eq([user.email_address])
    expect(last_email.subject).to eq("Unlock your account")
    expect(last_email.text_part.body.to_s).to include(user.unlock_token)
  end

  it "tells a locked account with the correct password that it is locked, but not one with a wrong password" do
    user = create_user(locked_at: Time.current, unlock_token: "abc", failed_attempts: 5)

    sign_in user
    follow_redirect!
    expect(response.body).to include("Your account is locked")

    sign_in user, password: "wrong"
    follow_redirect!
    expect(response.body).to include("Try another email address or password.")
    expect(response.body).not_to include("locked")
  end

  it "unlocks via the emailed token" do
    user = create_user
    5.times { sign_in user, password: "wrong" }

    get "/unlocks/#{user.reload.unlock_token}"
    expect(response).to redirect_to("/session/new")
    expect(user.reload).not_to be_locked
    expect(user.failed_attempts).to eq(0)

    sign_in user
    expect(response).to redirect_to("http://www.example.com/")
  end

  it "lets the lock expire on its own after an hour" do
    user = create_user
    5.times { sign_in user, password: "wrong" }

    travel 61.minutes do
      sign_in user

      expect(response).to redirect_to("http://www.example.com/")
      expect(user.reload.failed_attempts).to eq(0)
      expect(user.locked_at).to be_nil
    end
  end

  it "resends unlock instructions to locked accounts only" do
    locked = create_user(email: "locked@example.com", locked_at: Time.current, unlock_token: "abc")
    unlocked = create_user(email: "fine@example.com")

    post "/unlocks", params: { email_address: locked.email_address }
    expect(last_email.to).to eq(["locked@example.com"])

    ActionMailer::Base.deliveries.clear
    post "/unlocks", params: { email_address: unlocked.email_address }
    expect(ActionMailer::Base.deliveries).to be_empty
  end
end

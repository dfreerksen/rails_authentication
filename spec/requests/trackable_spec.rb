# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Authentication tracking (trackable)", type: :request do
  it "records successful sign-ins" do
    user = create_user

    expect { sign_in user }.to change(UserAuth.successful, :count).by(1)

    auth = UserAuth.successful.last
    expect(auth.user).to eq(user)
    expect(auth.ip).to eq("127.0.0.1")
    expect(auth.failure_reason).to be_nil
  end

  it "records failed attempts with a reason" do
    user = create_user

    expect { sign_in user, password: "wrong" }.to change(UserAuth.failed, :count).by(1)

    auth = UserAuth.failed.last
    expect(auth.user).to eq(user)
    expect(auth.failure_reason).to eq("invalid_credentials")
  end

  it "records attempts against unknown email addresses without a user" do
    expect {
      post "/session", params: { email_address: "ghost@example.com", password: "wrong" }
    }.to change(UserAuth.failed, :count).by(1)

    expect(UserAuth.failed.last.user).to be_nil
  end

  it "records blocked sign-ins on unconfirmed accounts" do
    user = create_user(confirmed: false)

    sign_in user

    expect(UserAuth.failed.last.failure_reason).to eq("unconfirmed")
  end
end

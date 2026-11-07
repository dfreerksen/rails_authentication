# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Remember me (rememberable)" do
  it "stamps the session and issues a persistent cookie when remember me is checked" do
    user = create_user

    sign_in user, remember: true

    expect(user.sessions.sole).to be_remembered
    expect(session_cookie_header).to match(/expires=/i)
  end

  it "issues a browser-session cookie and leaves the session unstamped when remember me is unchecked" do
    user = create_user

    sign_in user

    expect(user.sessions.sole).not_to be_remembered
    expect(session_cookie_header).not_to match(/expires=/i)
  end

  it "remembers per device: signing in elsewhere without remember me leaves this device remembered" do
    user = create_user
    sign_in user, remember: true
    remembered = user.sessions.sole

    other_device = open_session
    other_device.post "/session", params: { email_address: user.email_address, password: RequestHelpers::PASSWORD }

    expect(user.sessions.count).to eq(2)
    expect(remembered.reload).to be_remembered
    expect(user.sessions.where.not(id: remembered.id).sole).not_to be_remembered
  end

  it "signing out on one device leaves the other device remembered" do
    user = create_user
    other_device = open_session
    params = { email_address: user.email_address, password: RequestHelpers::PASSWORD, remember_me: "1" }
    other_device.post "/session", params: params
    sign_in user

    sign_out

    expect(user.sessions.sole).to be_remembered
  end

  def session_cookie_header
    Array(response.headers["set-cookie"]).join("\n")[/session_id=[^\n]*/] || ""
  end
end

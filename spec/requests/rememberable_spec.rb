# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Remember me (rememberable)", type: :request do
  it "stamps remember_created_at and issues a persistent cookie when remember me is checked" do
    user = create_user

    sign_in user, remember: true

    expect(user.reload).to be_remembered
    expect(session_cookie_header).to match(/expires=/i)
  end

  it "issues a browser-session cookie and clears the stamp when remember me is unchecked" do
    user = create_user(remember_created_at: 1.day.ago)

    sign_in user

    expect(user.reload).not_to be_remembered
    expect(session_cookie_header).not_to match(/expires=/i)
  end

  it "forgets the user on sign-out" do
    user = create_user
    sign_in user, remember: true
    expect(user.reload).to be_remembered

    sign_out

    expect(user.reload).not_to be_remembered
  end

  def session_cookie_header
    Array(response.headers["set-cookie"]).join("\n")[/session_id=[^\n]*/] || ""
  end
end

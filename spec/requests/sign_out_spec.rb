# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Signing out" do
  it "ends the session and confirms it on the sign-in page" do
    user = create_user
    sign_in user

    sign_out

    expect(response).to redirect_to("/session/new")
    expect(user.sessions.count).to eq(0)

    follow_redirect!
    expect(response.body).to include("You have been signed out.")
  end
end

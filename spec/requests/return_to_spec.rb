# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Returning to the requested page after sign-in" do
  let!(:user) { create_user }

  it "sends the user back to the page they were redirected away from" do
    get "/registration/edit"
    expect(response).to redirect_to("/session/new")

    sign_in user

    expect(response).to redirect_to("/registration/edit")
  end

  it "only returns there once" do
    get "/registration/edit"
    sign_in user
    sign_out

    sign_in user

    expect(response).to redirect_to("/")
  end

  it "falls back to the default when there was no page to return to" do
    sign_in user

    expect(response).to redirect_to("/")
  end

  it "doesn't return to a form submission" do
    patch "/registration", params: { email: "new@example.com" }
    expect(response).to redirect_to("/session/new")

    sign_in user

    expect(response).to redirect_to("/")
  end

  it "doesn't return to a JSON endpoint" do
    get "/registration/edit", as: :json

    sign_in user

    expect(response).to redirect_to("/")
  end
end

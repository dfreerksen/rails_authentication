# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Session timeout (timeoutable)", type: :request do
  it "expires inactive sessions" do
    user = create_user
    sign_in user
    get "/"
    expect(response).to have_http_status(:ok)

    travel 31.minutes do
      get "/"

      expect(response).to redirect_to("/session/new")
      expect(user.sessions.count).to eq(0)
    end
  end

  it "keeps sessions alive while they are active" do
    user = create_user
    sign_in user

    travel 20.minutes do
      get "/"
      expect(response).to have_http_status(:ok)
    end

    travel 40.minutes do
      get "/" # still within 30 minutes of the touch above
      expect(response).to have_http_status(:ok)
    end
  end

  it "does not time out remembered users" do
    user = create_user
    sign_in user, remember: true

    travel 31.minutes do
      get "/"
      expect(response).to have_http_status(:ok)
    end
  end
end

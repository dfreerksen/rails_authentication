# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Session timeout (timeoutable)" do
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

  it "does not time out remembered sessions" do
    user = create_user
    sign_in user, remember: true

    travel 31.minutes do
      get "/"
      expect(response).to have_http_status(:ok)
    end
  end

  it "expires remembered sessions after REMEMBERED_TIMEOUT_IN of inactivity" do
    user = create_user
    sign_in user, remember: true

    travel Session::REMEMBERED_TIMEOUT_IN + 1.minute do
      get "/"

      expect(response).to redirect_to("/session/new")
      expect(user.sessions.count).to eq(0)
    end
  end

  it "slides the remembered expiry forward with each visit" do
    user = create_user
    sign_in user, remember: true
    signed_in_at = Time.current

    travel_to(signed_in_at + 60.days) do
      get "/"
      expect(response).to have_http_status(:ok)
    end

    travel_to(signed_in_at + 120.days) do # past REMEMBERED_TIMEOUT_IN since sign-in, 60 days since the last visit
      get "/"
      expect(response).to have_http_status(:ok)
    end

    travel_to(signed_in_at + 120.days + Session::REMEMBERED_TIMEOUT_IN + 1.minute) do
      get "/"
      expect(response).to redirect_to("/session/new")
      expect(user.sessions.count).to eq(0)
    end
  end

  describe "Session.expired" do
    it "selects timed-out unremembered sessions and long-idle remembered ones" do
      user = create_user

      idle = user.sessions.create!(updated_at: 31.minutes.ago)
      fresh = user.sessions.create!
      remembered_recent = user.sessions.create!(remembered_at: 1.day.ago, updated_at: 31.minutes.ago)
      remembered_stale = user.sessions.create!(remembered_at: 100.days.ago,
                                               updated_at: (Session::REMEMBERED_TIMEOUT_IN + 1.minute).ago)

      expect(Session.expired).to contain_exactly(idle, remembered_stale)
      expect([idle, fresh, remembered_recent, remembered_stale].map(&:expired?)).to eq([true, false, false, true])
    end
  end
end

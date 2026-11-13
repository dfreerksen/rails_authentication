# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Invitations (invitable)" do
  it "sends an invitation" do
    inviter = create_user(email: "inviter@example.com")
    sign_in inviter

    expect do
      post "/invitations", params: { email: "invitee@example.com" }
    end.to change(User, :count).by(1)

    invitee = User.find_by!(email: "invitee@example.com")
    expect(invitee.invitation_token).to be_present
    expect(invitee.invited_by).to eq(inviter)
    expect(inviter.reload.invitations_count).to eq(1)
    expect(last_email.to).to eq(["invitee@example.com"])
    expect(last_email.text_part.body.to_s).to include(invitee.invitation_token)
  end

  it "lets the invitee accept the invitation by setting a password" do
    inviter = create_user(email: "inviter@example.com")
    invitee = User.invite!({ email: "invitee@example.com" }, invited_by: inviter)

    patch "/invitations/#{invitee.invitation_token}",
          params: { password: "chosenpassword1", password_confirmation: "chosenpassword1" }

    expect(response).to redirect_to("http://www.example.com/")
    invitee.reload
    expect(invitee.invitation_token).to be_nil
    expect(invitee.invitation_accepted_at).to be_present
    expect(invitee).to be_confirmed # accepting the invite proves the email address

    get "/"
    expect(response).to have_http_status(:ok)
  end

  it "rejects a blank password, leaving the invitation pending and the invitee signed out" do
    invitee = User.invite!({ email: "invitee@example.com" })
    token = invitee.invitation_token

    patch "/invitations/#{token}", params: { password: "", password_confirmation: "" }

    expect(response).to redirect_to("/invitations/#{token}/edit")
    expect(flash[:alert]).to include("Password can't be blank")
    expect(invitee.reload).to be_invitation_pending
    expect(invitee.sessions.count).to eq(0)
  end

  it "requires authentication to send invitations" do
    post "/invitations", params: { email: "invitee@example.com" }

    expect(response).to redirect_to("/session/new")
    expect(User.find_by(email: "invitee@example.com")).to be_nil
  end

  it "re-invites a pending invitee instead of failing on the duplicate email" do
    inviter = create_user(email: "inviter@example.com")
    sign_in inviter
    post "/invitations", params: { email: "invitee@example.com" }
    first_token = User.find_by!(email: "invitee@example.com").invitation_token

    expect do
      post "/invitations", params: { email: "invitee@example.com" }
    end.not_to change(User, :count)

    expect(User.find_by!(email: "invitee@example.com").invitation_token).not_to eq(first_token)
    expect(inviter.reload.invitations_count).to eq(2)
  end

  it "blocks sign-in for a pending invitee, but not once the invitation is accepted" do
    invitee = create_user(email: "invitee@example.com", invitation_token: "abc", invitation_created_at: Time.current,
                          invitation_accepted_at: nil)

    sign_in invitee
    follow_redirect!
    expect(response.body).to include("You must accept your invitation before signing in.")

    patch "/invitations/abc", params: { password: "password123", password_confirmation: "password123" }
    sign_in invitee.reload
    expect(response).to redirect_to("http://www.example.com/")
  end

  it "rejects expired invitation tokens" do
    inviter = create_user(email: "inviter@example.com")
    sign_in inviter
    post "/invitations", params: { email: "invitee@example.com" }
    token = User.find_by!(email: "invitee@example.com").invitation_token
    sign_out

    travel 8.days do
      patch "/invitations/#{token}", params: { password: "chosenpassword1", password_confirmation: "chosenpassword1" }

      expect(response).to redirect_to("/session/new")
      expect(User.find_by!(email: "invitee@example.com").invitation_accepted_at).to be_nil
    end
  end

  it "shows validation errors and sends nothing when the invitee's attributes are invalid" do
    inviter = create_user(email: "inviter@example.com")
    sign_in inviter
    ActionMailer::Base.deliveries.clear

    expect do
      post "/invitations", params: { email: "not-an-email" }
    end.not_to change(User, :count)

    expect(response).to redirect_to("/invitations/new")
    follow_redirect!
    expect(response.body).to include("Email is invalid")
    expect(ActionMailer::Base.deliveries).to be_empty
    expect(inviter.reload.invitations_count).to eq(0)
  end

  describe "User.invite!" do
    it "builds the invitee from an attributes hash, not just an email address" do
      confirmed_at = 1.day.ago.change(usec: 0)

      invitee = User.invite!({ email: "invitee@example.com", confirmed_at: confirmed_at })

      expect(invitee).to be_persisted
      expect(invitee.email).to eq("invitee@example.com")
      expect(invitee.confirmed_at).to eq(confirmed_at)
      expect(invitee.invitation_token).to be_present
      expect(invitee.invitation_sent_at).to be_present
      expect(last_email.to).to eq(["invitee@example.com"])
    end

    it "accepts string keys and permitted ActionController::Parameters" do
      from_hash = User.invite!({ "email" => "string-keys@example.com" })
      from_params = User.invite!(ActionController::Parameters.new(email: "params@example.com")
                        .permit(:email))

      expect(from_hash).to be_persisted
      expect(from_params).to be_persisted
      expect(from_params.email).to eq("params@example.com")
    end

    it "always sets a generated temporary password, ignoring any password passed in" do
      invitee = User.invite!({ email: "invitee@example.com", password: "Chosen-by-inviter1" })

      expect(invitee).to be_persisted
      expect(invitee.authenticate("Chosen-by-inviter1")).to be(false)
    end

    it "records the inviter" do
      inviter = create_user(email: "inviter@example.com")

      invitee = User.invite!({ email: "invitee@example.com" }, invited_by: inviter)

      expect(invitee.invited_by).to eq(inviter)
      expect(inviter.reload.invitations_count).to eq(1)
    end

    it "returns an unsaved user with errors when the attributes are invalid" do
      ActionMailer::Base.deliveries.clear

      invitee = User.invite!({ email: "not-an-email" })

      expect(invitee).not_to be_persisted
      expect(invitee.errors[:email]).to be_present
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "returns an existing, non-pending user untouched, ignoring the other attributes" do
      existing = create_user(email: "member@example.com")
      ActionMailer::Base.deliveries.clear

      result = User.invite!({ email: "member@example.com", confirmed_at: nil })

      expect(result).to eq(existing)
      expect(result.reload).to be_confirmed
      expect(result.invitation_token).to be_nil
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end
end

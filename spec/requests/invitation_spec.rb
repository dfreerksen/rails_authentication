# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Invitations (invitable)", type: :request do
  it "invites a user who accepts by setting a password" do
    inviter = create_user(email: "inviter@example.com")
    sign_in inviter

    expect {
      post "/invitations", params: { email_address: "invitee@example.com" }
    }.to change(User, :count).by(1)

    invitee = User.find_by!(email_address: "invitee@example.com")
    expect(invitee.invitation_token).to be_present
    expect(invitee.invited_by).to eq(inviter)
    expect(inviter.reload.invitations_count).to eq(1)
    expect(last_email.to).to eq(["invitee@example.com"])
    expect(last_email.text_part.body.to_s).to include(invitee.invitation_token)

    sign_out

    patch "/invitations/#{invitee.reload.invitation_token}",
      params: { password: "chosenpassword1", password_confirmation: "chosenpassword1" }

    expect(response).to redirect_to("http://www.example.com/")
    invitee.reload
    expect(invitee.invitation_token).to be_nil
    expect(invitee.invitation_accepted_at).to be_present
    expect(invitee).to be_confirmed # accepting the invite proves the email address

    get "/"
    expect(response).to have_http_status(:ok)
  end

  it "requires authentication to send invitations" do
    post "/invitations", params: { email_address: "invitee@example.com" }

    expect(response).to redirect_to("/session/new")
    expect(User.find_by(email_address: "invitee@example.com")).to be_nil
  end

  it "re-invites a pending invitee instead of failing on the duplicate email" do
    inviter = create_user(email: "inviter@example.com")
    sign_in inviter
    post "/invitations", params: { email_address: "invitee@example.com" }
    first_token = User.find_by!(email_address: "invitee@example.com").invitation_token

    expect {
      post "/invitations", params: { email_address: "invitee@example.com" }
    }.not_to change(User, :count)

    expect(User.find_by!(email_address: "invitee@example.com").invitation_token).not_to eq(first_token)
    expect(inviter.reload.invitations_count).to eq(2)
  end

  it "blocks sign-in for a pending invitee, but not once the invitation is accepted" do
    invitee = create_user(email: "invitee@example.com", invitation_token: "abc", invitation_created_at: Time.current, invitation_accepted_at: nil)

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
    post "/invitations", params: { email_address: "invitee@example.com" }
    token = User.find_by!(email_address: "invitee@example.com").invitation_token
    sign_out

    travel 8.days do
      patch "/invitations/#{token}", params: { password: "chosenpassword1", password_confirmation: "chosenpassword1" }

      expect(response).to redirect_to("/session/new")
      expect(User.find_by!(email_address: "invitee@example.com").invitation_accepted_at).to be_nil
    end
  end
end

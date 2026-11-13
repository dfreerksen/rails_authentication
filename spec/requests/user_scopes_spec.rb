# frozen_string_literal: true

require "rails_helper"

RSpec.describe "User scopes" do
  let!(:users) do
    {
      plain: create_user(email: "plain@example.com"),
      unconfirmed: create_user(email: "unconfirmed@example.com", confirmed: false),
      locked: create_user(email: "locked@example.com", locked_at: 10.minutes.ago),
      lock_expired: create_user(email: "lock-expired@example.com",
                                locked_at: (LockableConcern::UNLOCK_IN + 1.minute).ago),
      invitation_pending: create_user(email: "pending@example.com",
                                      invitation_token: "pending-token", invitation_created_at: Time.current),
      invitation_accepted: create_user(email: "accepted@example.com", invitation_accepted_at: 1.day.ago)
    }
  end

  def users_except(*names)
    users.except(*names).values
  end

  it "scopes locks like locked?" do
    expect(User.locked).to contain_exactly(users[:locked])
    expect(User.not_locked).to match_array(users_except(:locked))
  end

  it "scopes pending invitations like invitation_pending?, ignoring users who were never invited" do
    expect(User.pending).to contain_exactly(users[:invitation_pending])
    expect(User.not_pending).to match_array(users_except(:invitation_pending))
    expect(User.accepted).to contain_exactly(users[:invitation_accepted])
  end

  it "splits users into available and unavailable by whether they can sign in" do
    expect(User.available).to contain_exactly(users[:plain], users[:lock_expired], users[:invitation_accepted])
    expect(User.unavailable).to contain_exactly(users[:unconfirmed], users[:locked], users[:invitation_pending])
  end

  it "agrees with the instance checks the sign-in flows use" do
    users.each_value do |user|
      can_sign_in = user.confirmed? && !user.locked? && !user.invitation_pending?
      expect(User.available.exists?(user.id))
        .to eq(can_sign_in), "#{user.email}: expected available=#{can_sign_in}"
    end
  end

  it "has instance predicates that agree with the scopes" do
    users.each_value do |user|
      in_scope = User.available.exists?(user.id)
      expect([user.available?, user.active_for_authentication?, user.unavailable?])
        .to eq([in_scope, in_scope, !in_scope]), "#{user.email}: expected available?=#{in_scope}"
    end
  end

  it "composes with other conditions" do
    expect(User.where(email: %w[plain@example.com locked@example.com]).unavailable)
      .to contain_exactly(users[:locked])
  end
end

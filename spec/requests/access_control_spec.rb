# frozen_string_literal: true

require "rails_helper"

# require_authenticated_access isn't used by any generated controller, so these throwaway
# controllers exercise it. The important guarantee: it only ever adds protection. It must never
# replace the global require_authentication callback (which re-registering that callback with
# only:/except: would do) and leave the remaining actions public.
RSpec.describe "Access control class methods" do
  before do
    stub_const("AccessSpec::ReopenedController", Class.new(ApplicationController) do
      allow_unauthenticated_access
      require_authenticated_access only: :secret

      def public_page = render(plain: "public")
      def secret = render(plain: "secret")
    end)

    stub_const("AccessSpec::NarrowedController", Class.new(ApplicationController) do
      require_authenticated_access only: :one

      def one = render(plain: "one")
      def two = render(plain: "two")
    end)
  end

  around do |example|
    with_routing do |routes|
      routes.draw do
        resource :session
        root "home#index"
        get "reopened/public_page", to: "access_spec/reopened#public_page"
        get "reopened/secret", to: "access_spec/reopened#secret"
        get "narrowed/one", to: "access_spec/narrowed#one"
        get "narrowed/two", to: "access_spec/narrowed#two"
      end
      example.run
    end
  end

  it "re-protects only the named actions of a controller opened with allow_unauthenticated_access" do
    get "/reopened/public_page"
    expect(response.body).to eq("public")

    get "/reopened/secret"
    expect(response).to redirect_to("/session/new")
  end

  it "never narrows the default: actions it doesn't name still require sign-in" do
    get "/narrowed/one"
    expect(response).to redirect_to("/session/new")

    get "/narrowed/two"
    expect(response).to redirect_to("/session/new")
  end

  it "lets a signed-in user through" do
    sign_in create_user

    get "/reopened/secret"
    expect(response.body).to eq("secret")

    get "/narrowed/two"
    expect(response.body).to eq("two")
  end
end

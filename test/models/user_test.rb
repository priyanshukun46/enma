require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid user saves with secure password and defaults to operator" do
    user = User.new(
      name: "Captain Roy",
      email_address: "roy@resqway.ai",
      password: "password123",
      password_confirmation: "password123"
    )
    assert user.valid?
    assert user.save
    assert_equal "operator", user.role
    assert user.operator?
    assert_not user.admin?
  end

  test "validates required fields and email uniqueness" do
    user1 = User.create!(
      name: "Officer 1",
      email_address: "unique@resqway.ai",
      password: "password123"
    )

    user2 = User.new(
      name: "Officer 2",
      email_address: "UNIQUE@resqway.ai",
      password: "password123"
    )
    assert_not user2.valid?
    assert_includes user2.errors[:email_address], "has already been taken"
  end

  test "validates minimum password length" do
    user = User.new(
      name: "Short Pass",
      email_address: "short@resqway.ai",
      password: "123"
    )
    assert_not user.valid?
    assert_includes user.errors[:password], "must be at least 8 characters long"
  end

  test "from_omniauth creates new user or links existing user safely" do
    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "123456789",
      info: {
        name: "Google Officer",
        email: "google.officer@resqway.ai",
        image: "https://example.com/avatar.png"
      }
    )

    # 1. First time OAuth user creation
    user = User.from_omniauth(auth)
    assert_equal "google.officer@resqway.ai", user.email_address
    assert_equal "google_oauth2", user.provider
    assert_equal "123456789", user.uid
    assert_equal "operator", user.role

    # 2. Subsequent OAuth login with same provider & uid
    same_user = User.from_omniauth(auth)
    assert_equal user.id, same_user.id

    # 3. Linking existing email/password user with OAuth
    existing = User.create!(
      name: "Existing Admin",
      email_address: "admin.link@resqway.ai",
      password: "password123",
      role: :admin
    )

    github_auth = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "987654321",
      info: {
        name: "Existing Admin GitHub",
        email: "admin.link@resqway.ai"
      }
    )

    linked_user = User.from_omniauth(github_auth)
    assert_equal existing.id, linked_user.id
    assert_equal "admin", linked_user.role # Role must NOT be overwritten!
  end

  test "generates and verifies password reset token" do
    user = User.create!(
      name: "Token User",
      email_address: "token@resqway.ai",
      password: "password123"
    )

    token = user.generate_token_for(:password_reset)
    assert_not_nil token

    found = User.find_by_token_for(:password_reset, token)
    assert_equal user.id, found.id
  end
end

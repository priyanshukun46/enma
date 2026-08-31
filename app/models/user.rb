class User < ApplicationRecord
  has_secure_password validations: false

  has_many :incidents, dependent: :nullify

  enum :role, { operator: "operator", admin: "admin" }, default: :operator

  normalizes :email_address, with: ->(e) { e.to_s.strip.downcase }
  normalizes :username, with: ->(u) { u.to_s.strip.downcase.presence }

  generates_token_for :password_reset, expires_in: 20.minutes do
    password_salt&.last(10)
  end

  before_validation :derive_username_if_blank

  validates :name, presence: true
  validates :email_address, presence: true,
                            uniqueness: { case_sensitive: false },
                            format: { with: URI::MailTo::EMAIL_REGEXP, message: "is not a valid email address" }

  validates :username, uniqueness: { case_sensitive: false, allow_nil: true },
                       format: { with: /\A[a-zA-Z0-9_.]+\z/, message: "can only contain letters, numbers, underscores and dots", allow_nil: true }

  validates :password, length: { minimum: 8, message: "must be at least 8 characters long" },
                       confirmation: true,
                       if: -> { password.present? }
  validates :password, presence: true,
                       if: -> { provider.blank? && password_digest.blank? }

  # Find user by either username, email address, or name
  def self.find_by_login(identifier)
    clean_id = identifier.to_s.strip.downcase
    return nil if clean_id.blank?

    where("LOWER(email_address) = :id OR LOWER(username) = :id OR LOWER(name) = :id", id: clean_id).first
  end

  # OAuth find or create logic
  def self.from_omniauth(auth)
    return nil if auth.blank?

    provider = auth.provider.to_s
    uid = auth.uid.to_s
    info = auth.info || {}
    email = info.email.presence || "#{provider}_#{uid}@oauth.enma.ai"
    nickname = info.nickname.presence
    name = info.name.presence || nickname || "ENMA Intelligence Officer"
    avatar = info.image.presence

    # First attempt: find by existing provider + UID
    user = find_by(provider: provider, uid: uid)
    return user if user

    # Second attempt: find by email to link existing account safely
    user = find_by(email_address: email.downcase)
    if user
      user.update(provider: provider, uid: uid, avatar_url: user.avatar_url.presence || avatar, username: user.username.presence || nickname)
      return user
    end

    # Third attempt: create new user defaulting to operator
    create!(
      name: name,
      username: nickname,
      email_address: email.downcase,
      provider: provider,
      uid: uid,
      avatar_url: avatar,
      role: :operator
    )
  end

  def role_badge_class
    if admin?
      "bg-purple-100 text-purple-800 border-purple-300 font-black"
    else
      "bg-blue-100 text-blue-800 border-blue-300 font-bold"
    end
  end

  def provider_label
    case provider.to_s.downcase
    when "google_oauth2", "google" then "Google"
    when "github" then "GitHub"
    else "Username / Password"
    end
  end

  def provider_icon
    case provider.to_s.downcase
    when "google_oauth2", "google" then "fab fa-google text-red-500"
    when "github" then "fab fa-github text-gray-900"
    else "fas fa-key text-indigo-600"
    end
  end

  def initials
    parts = name.to_s.split
    if parts.size >= 2
      "#{parts.first[0]}#{parts.last[0]}".upcase
    elsif parts.size == 1
      parts.first[0, 2].upcase
    else
      "EA"
    end
  end

  private

  def derive_username_if_blank
    if username.blank? && email_address.present?
      base_user = email_address.split("@").first.to_s.gsub(/[^a-zA-Z0-9_.]/, "")
      if base_user.present?
        candidate = base_user
        counter = 1
        while User.where.not(id: id).exists?(username: candidate.downcase)
          candidate = "#{base_user}_#{counter}"
          counter += 1
        end
        self.username = candidate.downcase
      end
    end
  end
end

class User < ApplicationRecord
  # Devise Modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  attr_accessor :login

  has_many :incidents, dependent: :nullify

  enum :role, { operator: "operator", admin: "admin" }, default: :operator

  generates_token_for :password_reset, expires_in: 20.minutes do
    (encrypted_password.presence || read_attribute(:password_digest)).to_s.last(10)
  end

  before_validation :sync_email_fields
  before_validation :derive_username_if_blank

  validates :name, presence: true
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "is not a valid email address" }
  validates :email_address, uniqueness: { case_sensitive: false }, allow_nil: true

  validates :username, uniqueness: { case_sensitive: false, allow_nil: true },
                       format: { with: /\A[a-zA-Z0-9_.]+\z/, message: "can only contain letters, numbers, underscores and dots", allow_nil: true }

  validates :password, length: { minimum: 8, message: "must be at least 8 characters long" },
                       if: -> { password.present? }

  # Devise finder for authentication via either email or username
  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    if (login = conditions.delete(:login))
      clean_login = login.to_s.downcase.strip
      where(conditions.to_h).where(
        "LOWER(username) = :val OR LOWER(email) = :val OR LOWER(email_address) = :val",
        val: clean_login
      ).first
    elsif conditions.key?(:email) || conditions.key?(:username)
      where(conditions.to_h).first
    end
  end

  # Find user by identifier (login, email, username, or name)
  def self.find_by_login(identifier)
    clean_id = identifier.to_s.strip.downcase
    return nil if clean_id.blank?

    where(
      "LOWER(email) = :id OR LOWER(email_address) = :id OR LOWER(username) = :id OR LOWER(name) = :id",
      id: clean_id
    ).first
  end

  # Safeguard password_digest column accessor from clashing with Devise's password_digest(password) method
  def password_digest(*args)
    if args.empty?
      read_attribute(:password_digest)
    else
      super
    end
  end

  # Backward compatibility alias for has_secure_password authenticate method
  def authenticate(password)
    valid_password?(password) ? self : false
  end

  # Devise password verification with legacy fallback/upgrade
  def valid_password?(password)
    if encrypted_password.present?
      super(password)
    elsif read_attribute(:password_digest).present?
      valid = BCrypt::Password.new(read_attribute(:password_digest)) == password
      if valid
        self.encrypted_password = ::BCrypt::Password.create(password, cost: Devise.stretches).to_s
        save(validate: false)
      end
      valid
    else
      false
    end
  end

  # Ensure default demo accounts exist on demand
  def self.seed_demo_account(role_name)
    role_sym = role_name.to_s.strip.downcase == "admin" ? :admin : :operator
    uname = role_sym.to_s
    email = "#{uname}@resqway.ai"

    user = find_by(username: uname) || find_by(email: email) || find_by(email_address: email)
    return user if user

    create!(
      name: (role_sym == :admin ? "Priyanshu Kumar (Administrator)" : "Field Logistics Officer"),
      username: uname,
      email: email,
      email_address: email,
      password: "password123",
      password_confirmation: "password123",
      role: role_sym
    )
  rescue StandardError => e
    Rails.logger.error("Auto-provision demo account #{role_name} failed: #{e.message}")
    nil
  end

  def role_badge_class
    if admin?
      "bg-purple-100 text-purple-800 border-purple-300 font-black"
    else
      "bg-blue-100 text-blue-800 border-blue-300 font-bold"
    end
  end

  def provider_label
    "Username / Password"
  end

  def provider_icon
    "fas fa-key text-indigo-600"
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

  def sync_email_fields
    clean = (email.presence || email_address.presence).to_s.strip.downcase
    self.email = clean
    self.email_address = clean
  end

  def derive_username_if_blank
    if username.blank? && email.present?
      base_user = email.split("@").first.to_s.gsub(/[^a-zA-Z0-9_.]/, "")
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

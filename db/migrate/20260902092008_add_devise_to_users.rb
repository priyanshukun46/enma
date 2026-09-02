# frozen_string_literal: true

class AddDeviseToUsers < ActiveRecord::Migration[8.1]
  def up
    change_table :users do |t|
      ## Database authenticatable
      t.string :email
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at
    end

    # Backfill email from email_address and encrypted_password from password_digest
    execute "UPDATE users SET email = LOWER(email_address) WHERE email IS NULL OR email = ''"
    execute "UPDATE users SET encrypted_password = password_digest WHERE password_digest IS NOT NULL AND password_digest != ''"
    change_column_null :users, :email, false

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
  end

  def down
    remove_index :users, :reset_password_token if index_exists?(:users, :reset_password_token)
    remove_index :users, :email if index_exists?(:users, :email)
    remove_columns :users, :email, :encrypted_password, :reset_password_token, :reset_password_sent_at, :remember_created_at
  end
end

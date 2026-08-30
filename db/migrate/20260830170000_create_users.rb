class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email_address, null: false
      t.string :password_digest
      t.string :role, null: false, default: "operator"
      t.string :provider
      t.string :uid
      t.string :avatar_url

      t.timestamps
    end

    add_index :users, :email_address, unique: true
    add_index :users, [:provider, :uid]
  end
end

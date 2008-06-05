class AddModelAccounts < ActiveRecord::Migration
  def self.up
    create_table :accounts do |t|
      t.column :name, :string
      t.column :login,                     :string
      t.column :email,                     :string
      t.column :crypted_password,          :string, :limit => 40
      t.column :salt,                      :string, :limit => 40
      t.column :remember_token,            :string
      t.column :remember_token_expires_at, :datetime
      t.column :token, :string
      t.column :upload_redirect_url, :string
      t.column :state_update_url, :string
      t.column :updated_at, :datetime
      t.column :created_at, :datetime
    end    
  end

  def self.down
    drop_table :accounts
  end
end

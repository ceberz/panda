class AddModelInvites < ActiveRecord::Migration
  def self.up
    create_table :invites do |t|
      t.column :email, :string
      t.column :approved, :datetime
      t.column :account_id, :integer
      t.column :updated_at, :datetime
      t.column :created_at, :datetime
    end
  end

  def self.down
    drop_table :invites
  end
end

class AddModelNotifications < ActiveRecord::Migration
  def self.up
    create_table :notifications do |t|
      t.column :encoding_id, :integer
      t.column :tries, :integer
      t.column :response, :string
      t.column :state, :string # success, error (contacting client)
      t.column :updated_at, :datetime
      t.column :created_at, :datetime
    end
  end

  def self.down
    drop_table :jobs
  end
end

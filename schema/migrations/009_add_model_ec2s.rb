class AddModelEc2s < ActiveRecord::Migration
  def self.up
    create_table :ec2s do |t|
      t.column :amazon_id, :string
      t.column :address, :string
      t.column :instance_type, :string
      t.column :started_at, :datetime
      t.column :shutdown_at, :datetime
      t.column :updated_at, :datetime
      t.column :created_at, :datetime
    end
  end

  def self.down
    drop_table :jobs
  end
end

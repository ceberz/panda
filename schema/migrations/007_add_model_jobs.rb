class AddModelJobs < ActiveRecord::Migration
  def self.up
    create_table :jobs do |t|
      t.column :video_id, :integer
      t.column :ec2_id, :integer
      t.column :status, :string
      t.column :result, :text
      t.column :force, :boolean # Force re-encoding of already encoded files
      t.column :encoding_time, :integer
      t.column :updated_at, :datetime
      t.column :created_at, :datetime
    end
  end

  def self.down
    drop_table :jobs
  end
end

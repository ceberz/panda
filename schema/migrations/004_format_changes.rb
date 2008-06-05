class FormatChanges < ActiveRecord::Migration
  def self.up
    remove_column :formats, :name
    remove_column :formats, :resolution
    add_column :formats, :width, :integer
    add_column :formats, :height, :integer
    add_column :formats, :position, :integer
    add_column :formats, :format_id, :integer
    rename_table :formats, :qualities
    
    remove_column :videos, :resolution
    add_column :videos, :width, :integer
    add_column :videos, :height, :integer
    
    remove_column :encodings, :resolution
    add_column :encodings, :width, :integer
    add_column :encodings, :height, :integer
    
    create_table :formats do |t|
      t.column :name, :string
      t.column :format, :string
      
      t.column :updated_at, :datetime
      t.column :created_at, :datetime
    end
    
    rename_column :encodings, :format_id, :quality_id
  end

  def self.down
  end
end

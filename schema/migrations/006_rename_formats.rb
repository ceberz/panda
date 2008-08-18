class RenameFormats < ActiveRecord::Migration
  def self.up
    rename_column :formats, :format, :code
  end

  def self.down
  end
end

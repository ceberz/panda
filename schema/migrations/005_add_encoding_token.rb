class AddEncodingToken < ActiveRecord::Migration
  def self.up
    add_column :encodings, :token, :string
  end

  def self.down
  end
end

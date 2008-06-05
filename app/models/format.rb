class Format < ActiveRecord::Base
  has_many :qualities, :order => "position asc"
end
require File.join(File.dirname(__FILE__), "..", 'spec_helper.rb')

describe Profiles, "index action" do
  before(:each) do
    dispatch_to(Profiles, :index)
  end
end
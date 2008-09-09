require File.join(File.dirname(__FILE__), '..', 'spec_helper.rb')
require 'job_queue.rb'
require 'notify_queue.rb'

describe NotifyQueue, "instantiation" do
  before(:each) do    
    Panda::Config[:account_name] = "Humanized Phrase"
    Panda::Config[:default_timeout] = 42
  end
  
  it "should connect to AWS:SQS with credentials specified in panda_init.rb" do
    mocked_sqs = stub_everything("mocked sqs")
    RightAws::SqsGen2Interface.should_receive(:new).once.with(an_instance_of(String), an_instance_of(String)).and_return { |id, key|
      id.should == Panda::Config[:access_key_id]
      key.should == Panda::Config[:secret_access_key]
      mocked_sqs
    }
    queue = NotifyQueue.new
  end
  
  it "should create a queue named appropriately from the namespace if such a queue does not exist" do
    mocked_sqs = stub_everything("mocked sqs")
    mocked_sqs.stub!(:queue_url_by_name).and_return(nil)
    mocked_sqs.should_receive(:create_queue).once.with("humanized_phrase_notify_queue", anything) 
    RightAws::SqsGen2Interface.stub!(:new).and_return(mocked_sqs)
    
    queue = NotifyQueue.new
  end
  
  it "should specify the correct timeout when making a new queue" do
    mocked_sqs = stub_everything("mocked sqs")
    mocked_sqs.stub!(:queue_url_by_name).and_return(nil)
    mocked_sqs.should_receive(:create_queue).once.with(anything, 42) 
    RightAws::SqsGen2Interface.stub!(:new).and_return(mocked_sqs)
    
    queue = NotifyQueue.new
  end
  
  it "should discover the URI for an existing queue" do
    mocked_sqs = stub_everything("mocked sqs")
    mocked_sqs.should_receive(:queue_url_by_name).once.with('humanized_phrase_notify_queue').and_return("queue URI")
    RightAws::SqsGen2Interface.stub!(:new).and_return(mocked_sqs)
    
    queue = NotifyQueue.new
  end
  
  it "should not try and create a new queue if a correctly named one exists" do
    mocked_sqs = stub_everything("mocked sqs")
    mocked_sqs.stub!(:queue_url_by_name).and_return(['queue URI'])
    mocked_sqs.should_not_receive(:create_queue)
    RightAws::SqsGen2Interface.stub!(:new).and_return(mocked_sqs)
    
    queue = NotifyQueue.new
  end
end
require File.join(File.dirname(__FILE__), '..', 'spec_helper.rb')
require 'job_queue.rb'

describe JobQueue, "instantiation" do
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
    queue = JobQueue.new
  end
  
  it "should create a queue named appropriately from the namespace if such a queue does not exist" do
    mocked_sqs = stub_everything("mocked sqs")
    mocked_sqs.stub!(:queue_url_by_name).and_return(nil)
    mocked_sqs.should_receive(:create_queue).once.with("humanized_phrase_job_queue", anything) 
    RightAws::SqsGen2Interface.stub!(:new).and_return(mocked_sqs)
    
    queue = JobQueue.new
  end
  
  it "should specify the correct timeout when making a new queue" do
    mocked_sqs = stub_everything("mocked sqs")
    mocked_sqs.stub!(:queue_url_by_name).and_return(nil)
    mocked_sqs.should_receive(:create_queue).once.with(anything, 42) 
    RightAws::SqsGen2Interface.stub!(:new).and_return(mocked_sqs)
    
    queue = JobQueue.new
  end
  
  it "should discover the URI for an existing queue" do
    mocked_sqs = stub_everything("mocked sqs")
    mocked_sqs.should_receive(:queue_url_by_name).once.with('humanized_phrase_job_queue').and_return("queue URI")
    RightAws::SqsGen2Interface.stub!(:new).and_return(mocked_sqs)
    
    queue = JobQueue.new
  end
  
  it "should not try and create a new queue if a correctly named one exists" do
    mocked_sqs = stub_everything("mocked sqs")
    mocked_sqs.stub!(:queue_url_by_name).and_return(['queue URI'])
    mocked_sqs.should_not_receive(:create_queue)
    RightAws::SqsGen2Interface.stub!(:new).and_return(mocked_sqs)
    
    queue = JobQueue.new
  end
end

describe JobQueue, "enqueueing" do
  before(:each) do
    Panda::Config[:account_name] = "Humanized Phrase"
    Panda::Config[:default_timeout] = 42
    
    @mocked_sqs = stub_everything("mocked sqs")
    @mocked_sqs.stub!(:queue_url_by_name).and_return("queue URI")
    RightAws::SqsGen2Interface.stub!(:new).and_return(@mocked_sqs)
    
    @queue = JobQueue.new
  end
  
  it "should enqueue serialized data (the SimpleDB id) from a video object" do
    # in this case all we really need is the SimpleDB key
    mocked_video = mock("mocked video")
    mocked_video.stub!(:key).and_return(42)
    
    @mocked_sqs.should_receive(:send_message).once.with(anything, mocked_video.key.to_s)
    
    @queue.enqueue(mocked_video)
  end
  
  it "should use the URI returned from creating a new queue" do
    alt_mocked_sqs = stub_everything("mocked sqs")
    alt_mocked_sqs.stub!(:queue_url_by_name).and_return(nil)
    alt_mocked_sqs.stub!(:create_queue).and_return("queue URI")
    RightAws::SqsGen2Interface.stub!(:new).and_return(alt_mocked_sqs)
    
    alt_mocked_sqs.should_receive(:send_message).once.with("queue URI", anything)
    mocked_message = stub_everything("message")
    
    new_queue = JobQueue.new
    new_queue.enqueue(mocked_message)
  end

  it "should use the URI returned from discovering an already existing queue" do
    mocked_message = stub_everything("message")
    @mocked_sqs.should_receive(:send_message).once.with("queue URI", anything)
    
    @queue.enqueue(mocked_message)
  end
  
end

describe JobQueue, "dequeueing" do
  before(:each) do
    Panda::Config[:account_name] = "Humanized Phrase"
    Panda::Config[:default_timeout] = 42
    
    @mocked_sqs = stub_everything("mocked sqs")
    @mocked_sqs.stub!(:list_queues).and_return(['humanized_phrase_job_queue'])
    @mocked_sqs.stub!(:queue_url_by_name).and_return("queue URI")
    @mocked_sqs.stub!(:receive_message).and_return([{
      "ReceiptHandle" => "receipt",
      "MD5OfBody" => "hash",
      "Body" => "42", 
      "MessageId" => "id" 
    }])
    RightAws::SqsGen2Interface.stub!(:new).and_return(@mocked_sqs)
    
    @queue = JobQueue.new
  end
  
  it "should return [] when the queue is empty" do
    mocked_video = stub_everything("mocked video")
    @mocked_sqs.stub!(:receive_message).and_return([])
    
    Video.should_not_receive(:find)
    
    @queue.dequeue(1).should == []
  end
  
  it "should return an sqs receipt and a video object based on the ID returned in the queue message" do
    mocked_video = stub_everything("mocked video")
    
    Video.should_receive(:find).once.with("42").and_return(mocked_video)
    
    result = @queue.dequeue(1)
    result.is_a?(Array).should == true
    message = result.first
    message.is_a?(Hash).should == true
    message[:video].should == mocked_video
    message[:receipt].should == "receipt"
  end
  
  it "should return an array with multiple video/receipt hash pairs" do
    first_mocked_video = stub_everything("mocked video")
    second_mocked_video = stub_everything("mocked video")
    
    @mocked_sqs.stub!(:receive_message).and_return([
      { "ReceiptHandle" => "receipt",
        "MD5OfBody" => "hash",
        "Body" => "42", 
        "MessageId" => "id" },
      { "ReceiptHandle" => "receipt",
        "MD5OfBody" => "hash",
        "Body" => "3.14", 
        "MessageId" => "id" }])
    
    Video.should_receive(:find).once.with("42").and_return(first_mocked_video)
    Video.should_receive(:find).once.with("3.14").and_return(second_mocked_video)
    
    result = @queue.dequeue(2)
    result.is_a?(Array).should == true
    result.size.should == 2
    
    message = result[0]
    message.is_a?(Hash).should == true
    message[:video].should == first_mocked_video
    message[:receipt].should == "receipt"
    
    message = result[1]
    message.is_a?(Hash).should == true
    message[:video].should == second_mocked_video
    message[:receipt].should == "receipt"
  end
  
  it "should remove from queue any jobs with bogus simpledb keys" do
    mocked_video = stub_everything("mocked video")
    
    Video.should_receive(:find).once.with("42").and_raise(Amazon::SDB::RecordNotFoundError)
    
    @mocked_sqs.should_receive(:delete_message).once.with(anything(), "receipt")
    
    result = @queue.dequeue(1).should == []
  end
  
  it "should try to pop the number of messages passed in as a parameter" do
    mocked_param = mock("param")
    @mocked_sqs.should_receive(:receive_message).once.with(anything, mocked_param).and_return([])
    
    @queue.dequeue(mocked_param)
  end
  
  it "should use the URI returned from creating a new queue" do
    alt_mocked_sqs = stub_everything("mocked sqs")
    alt_mocked_sqs.stub!(:queue_url_by_name).and_return(nil)
    alt_mocked_sqs.stub!(:create_queue).and_return("queue URI")
    RightAws::SqsGen2Interface.stub!(:new).and_return(alt_mocked_sqs)
    
    alt_mocked_sqs.should_receive(:receive_message).once.with("queue URI", anything).and_return([])
    
    new_queue = JobQueue.new
    new_queue.dequeue(1)
  end

  it "should use the URI returned from discovering an already existing queue" do
    @mocked_sqs.should_receive(:receive_message).once.with("queue URI", anything).and_return([])
    
    @queue.dequeue(1)
  end
  
end

describe JobQueue, "deleteing" do
  before(:each) do
    Panda::Config[:account_name] = "Humanized Phrase"
    Panda::Config[:default_timeout] = 42
    
    @mocked_sqs = stub_everything("mocked sqs")
    @mocked_sqs.stub!(:list_queues).and_return(['humanized_phrase_job_queue'])
    @mocked_sqs.stub!(:queue_url_by_name).and_return("queue URI")
    RightAws::SqsGen2Interface.stub!(:new).and_return(@mocked_sqs)
    
    @queue = JobQueue.new
  end
  
  it "should pass a given receipt to the sqs queue to delete the complete task" do
    @mocked_sqs.should_receive(:delete_message).once.with(anything, "receipt").and_return(true)
    
    @queue.delete("receipt")
  end
  
  it "should use the URI returned from creating a new queue" do
    alt_mocked_sqs = stub_everything("mocked sqs")
    alt_mocked_sqs.stub!(:queue_url_by_name).and_return(nil)
    alt_mocked_sqs.stub!(:create_queue).and_return("queue URI")
    RightAws::SqsGen2Interface.stub!(:new).and_return(alt_mocked_sqs)
    
    alt_mocked_sqs.should_receive(:delete_message).once.with("queue URI", anything)
    
    new_queue = JobQueue.new
    new_queue.delete("receipt")
  end

  it "should use the URI returned from discovering an already existing queue" do
    @mocked_sqs.should_receive(:delete_message).once.with("queue URI", anything)
    
    @queue.delete("receipt")
  end
end

describe JobQueue, "status" do
  before(:each) do
    Panda::Config[:account_name] = "Humanized Phrase"
    Panda::Config[:default_timeout] = 42
    
    @mocked_sqs = stub_everything("mocked sqs")
    @mocked_sqs.stub!(:list_queues).and_return(['humanized_phrase_job_queue'])
    @mocked_sqs.stub!(:queue_url_by_name).and_return("queue URI")
    RightAws::SqsGen2Interface.stub!(:new).and_return(@mocked_sqs)
    
    @queue = JobQueue.new
  end
  
  it "should provide the number of messages in the queue" do
    mocked_value = mock("mocked_value")
    @mocked_sqs.should_receive(:get_queue_length).once.with("queue URI").and_return(mocked_value)
    
    @queue.num_jobs.should == mocked_value
  end
end
require File.join(File.dirname(__FILE__), '..', 'spec_helper.rb')
require 'job_queue.rb'
require 'encoder_singleton.rb'
require 'notifier_singleton.rb'

describe NotifierSingleton, "job processing" do
  before(:each) do
    # no reason to sit around waiting
    NotifierSingleton.stub!(:sleep)  
    @mocked_video_1 = stub_everything("mocked video 1")
    @mocked_video_2 = stub_everything("mocked video 2")
                   
    @job_hash_1 = {:video => @mocked_video_1, :receipt => "receipt 1"}
    @job_hash_2 = {:video => @mocked_video_2, :receipt => "receipt 2"}
                   
    # to_yaml was breaking the specs; stub_everything apparently doesn't REALLY "stub everything"
    @mocked_video_1.stub!(:to_yaml).and_return(@mocked_video_1)
    @mocked_video_2.stub!(:to_yaml).and_return(@mocked_video_2)
    
    @mocked_job_queue = mock("mocked job queue")
    NotifyQueue.stub!(:new).and_return(@mocked_job_queue)
  end
  
  it "should pull notification tickets from the queue and process each in turn" do
    @mocked_job_queue.should_receive(:dequeue).once.with(1).and_return([@job_hash_1, @job_hash_2])
    @mocked_video_1.should_receive(:send_notification).once.ordered
    @mocked_video_1.should_receive(:delete_notification_job).once.ordered
    @mocked_video_2.should_receive(:send_notification).once
    @mocked_video_2.should_receive(:delete_notification_job).once.ordered
    
    NotifierSingleton.process_notifications
  end
  
  it "should only process notification tickets that are still marked as unsent in SimpleDB" do
    @mocked_job_queue.stub!(:dequeue).and_return([@job_hash_1, @job_hash_2])
    @mocked_video_1.stub!(:time_to_send_notification?).and_return(false)
    @mocked_video_1.should_not_receive(:send_notification)
    @mocked_video_1.should_not_receive(:delete_notification_job)
    
    @mocked_video_2.should_receive(:send_notification).once
    @mocked_video_2.should_receive(:delete_notification_job).once.ordered
    
    NotifierSingleton.process_notifications
  end
  
  it "should correctly handle any error that rises when sending the notification" do
    @mocked_job_queue.stub!(:dequeue).and_return([@job_hash_1])
    @mocked_video_1.stub!(:send_notification).and_raise(Exception)
    
    mocked_logger = stub_everything("mocked logger")
    Merb.stub!(:logger).and_return(mocked_logger)
    mocked_logger.should_receive(:error).once
    
    NotifierSingleton.process_notifications
  end
  
  it "should continue processing notifications should one of them fail" do
    @mocked_job_queue.stub!(:dequeue).and_return([@job_hash_1, @job_hash_2])
    @mocked_video_1.stub!(:send_notification).and_raise(Exception)
    
    mocked_logger = stub_everything("mocked logger")
    Merb.stub!(:logger).and_return(mocked_logger)
    
    @mocked_video_2.should_receive(:send_notification).once.ordered
    @mocked_video_2.should_receive(:delete_notification_job).once.ordered
    
    NotifierSingleton.process_notifications
  end
  
  it "should not delete a failed job from the queue" do
    @mocked_job_queue.stub!(:dequeue).and_return([@job_hash_1])
    @mocked_video_1.stub!(:send_notification).and_raise(Exception)
    @mocked_video_1.should_not_receive(:delete_notification_job)
    
    mocked_logger = stub_everything("mocked logger")
    Merb.stub!(:logger).and_return(mocked_logger)
    
    NotifierSingleton.process_notifications
  end  
end

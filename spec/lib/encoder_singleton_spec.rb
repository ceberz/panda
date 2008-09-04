require File.join(File.dirname(__FILE__), '..', 'spec_helper.rb')
require 'job_queue.rb'
require 'encoder_singleton.rb'

describe EncoderSingleton, "job processing" do
  before(:each) do
    @mocked_video_1 = stub_everything("mocked video 1")
    @mocked_video_2 = stub_everything("mocked video 2")
    
    # to_yaml was breaking the specs; stub_everything apparently doesn't REALLY "stub everything"
    @mocked_video_1.stub!(:to_yaml).and_return(@mocked_video_1)
    @mocked_video_2.stub!(:to_yaml).and_return(@mocked_video_2)
    
    @job_hashes = [{:video => @mocked_video_1, :receipt => "receipt 1"},
                   {:video => @mocked_video_2, :receipt => "receipt 2"}]
                   
    # no reason to sit around waiting
    EncoderSingleton.stub!(:sleep)
  end
  
  it "should fetch an array of jobs and then process each, encoding and then deleteing from the job queue" do
    Video.should_receive(:next_job).once.ordered.and_return(@job_hashes)
    
    @mocked_video_1.should_receive(:encode).once.ordered
    @mocked_video_1.should_receive(:delete_job).once.ordered.with("receipt 1")
    
    @mocked_video_2.should_receive(:encode).once.ordered
    @mocked_video_2.should_receive(:delete_job).once.ordered.with("receipt 2")
    
    EncoderSingleton.process_jobs
  end
  
  it "should not try to encode anything if Video::next_job returns no jobs" do
    Video.should_receive(:next_job).once.ordered.and_return([])
    
    @mocked_video_1.should_not_receive(:encode)
    @mocked_video_1.should_not_receive(:delete_job)
    
    @mocked_video_2.should_not_receive(:encode)
    @mocked_video_2.should_not_receive(:delete_job)
    
    EncoderSingleton.process_jobs
  end
  
  it "should not delete the job from the queue if encoding fails" do
    Video.should_receive(:next_job).once.ordered.and_return(@job_hashes)
    ErrorSender.stub!(:log_and_email)
    
    @mocked_video_1.should_receive(:encode).once.ordered.and_raise(Exception)
    @mocked_video_1.should_not_receive(:delete_job)
    
    EncoderSingleton.process_jobs
  end
  
  it "should continue processing jobs if one fails" do
    Video.should_receive(:next_job).once.ordered.and_return(@job_hashes)
    ErrorSender.stub!(:log_and_email)
    
    @mocked_video_1.should_receive(:encode).once.ordered.and_raise(Exception)
    
    @mocked_video_2.should_receive(:encode).once.ordered
    @mocked_video_2.should_receive(:delete_job).once.ordered.with("receipt 2")
    
    EncoderSingleton.process_jobs
  end
  
  it "should log an error on a failure" do
    Video.should_receive(:next_job).once.ordered.and_return(@job_hashes)
    
    @mocked_video_1.should_receive(:encode).once.ordered.and_raise(Exception)
    ErrorSender.should_receive(:log_and_email).once.ordered
    
    EncoderSingleton.process_jobs
  end
  
  it "should log a meta-error if normal error logging fails" do
    mocked_logger = mock("mocked logger")
    Video.should_receive(:next_job).once.ordered.and_return(@job_hashes)
    
    @mocked_video_1.should_receive(:encode).once.ordered.and_raise(Exception)
    ErrorSender.should_receive(:log_and_email).once.ordered.and_raise(Exception)
    Merb.should_receive(:logger).once.ordered.and_return(mocked_logger)
    mocked_logger.should_receive(:error).once.ordered
    
    EncoderSingleton.process_jobs
  end
end
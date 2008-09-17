require File.join(File.dirname(__FILE__), '..', 'spec_helper.rb')
require 'job_queue.rb'
require 'encoder_singleton.rb'

describe EncoderSingleton, "job counting" do
  before(:each) do
    EncoderSingleton.job_count = 1
  end
  
  it "should decrement the total job count" do
    EncoderSingleton.dec_job_count
    EncoderSingleton.job_count.should == 0
  end
  
  it "should increment the total job count" do
    EncoderSingleton.inc_job_count
    EncoderSingleton.job_count.should == 2
  end
end

describe EncoderSingleton, "job scheduling" do
  before(:each) do
    @mocked_video_1 = stub_everything("mocked video 1")
    @mocked_video_2 = stub_everything("mocked video 2")
    
    @mocked_video_1.stub!(:queued?).and_return(true)
    @mocked_video_2.stub!(:queued?).and_return(true)
    
    # to_yaml was breaking the specs; stub_everything apparently doesn't REALLY "stub everything"
    @mocked_video_1.stub!(:to_yaml).and_return(@mocked_video_1)
    @mocked_video_2.stub!(:to_yaml).and_return(@mocked_video_2)
    
    @job_hashes = [{:video => @mocked_video_1, :receipt => "receipt 1"},
                   {:video => @mocked_video_2, :receipt => "receipt 2"}]
                   
    # no reason to sit around waiting
    EncoderSingleton.stub!(:sleep)
    
    # stub out the mutex unless it needs to be mocked
    EncoderSingleton.job_mutex.stub!(:synchronize).and_yield
    
    Panda::Config[:max_pull_down] = 5
    EncoderSingleton.job_count = 0
    
    @mocked_logger = stub_everything()
    Merb.stub!(:logger).and_return(@mocked_logger)
  end
  
  it "should not request more jobs than the max setting" do
    Video.should_receive(:next_job).once.with(5).and_return([])
    
    EncoderSingleton.schedule_jobs
  end
  
  it "should not put the active job count past the max setting" do
    EncoderSingleton.job_count = 3
    
    Video.should_receive(:next_job).once.with(2).and_return([])
    
    EncoderSingleton.schedule_jobs
  end
  
  it "should start a thread to deal with each new valid job" do
    Video.stub!(:next_job).and_return(@job_hashes)
    
    Thread.should_receive(:new).once.ordered.with(@job_hashes[0]).and_yield(@job_hashes[0])
    EncoderSingleton.should_receive(:process_job).once.ordered.with(@job_hashes[0], anything())
      
    Thread.should_receive(:new).once.ordered.with(@job_hashes[1]).and_yield(@job_hashes[1])
    EncoderSingleton.should_receive(:process_job).once.ordered.with(@job_hashes[1], anything())
    
    EncoderSingleton.schedule_jobs
  end
  
  it "should safely increment the job count for each new valid job" do
    Video.stub!(:next_job).and_return(@job_hashes)
    
    EncoderSingleton.job_mutex.should_receive(:synchronize).twice.ordered.and_yield
    EncoderSingleton.should_receive(:inc_job_count).twice.ordered
    Thread.stub!(:new)
    
    EncoderSingleton.schedule_jobs
  end
  
  it "should pass a thread id to each job processor" do
    Video.stub!(:next_job).and_return(@job_hashes)
    
    Thread.should_receive(:new).twice.with(anything()).and_yield(stub_everything("dummy"))
    EncoderSingleton.should_receive(:process_job).twice.with(anything(), an_instance_of(Integer))
    
    EncoderSingleton.schedule_jobs
  end
  
  it "should only schedule jobs that have videos in the queued state" do
    @mocked_video_1.stub!(:queued?).and_return(false)
    
    Video.stub!(:next_job).and_return(@job_hashes)

    Thread.should_not_receive(:new).with(@job_hashes[0])
      EncoderSingleton.should_not_receive(:process_job).with(@job_hashes[0], anything())
      
    Thread.should_receive(:new).once.ordered.with(@job_hashes[1]).and_yield(@job_hashes[1])
      EncoderSingleton.should_receive(:process_job).once.ordered.with(@job_hashes[1], anything())
    
    EncoderSingleton.schedule_jobs
  end
  
  it "should increment the job count for jobs that have videos in the queued state" do
    @mocked_video_1.stub!(:queued?).and_return(false)
    @mocked_video_2.stub!(:queued?).and_return(false)
    
    Video.stub!(:next_job).and_return(@job_hashes)

    EncoderSingleton.job_mutex.should_not_receive(:synchronize)
    EncoderSingleton.should_not_receive(:inc_job_count)
    Thread.stub!(:new)
    
    EncoderSingleton.schedule_jobs
  end
  
  it "should remove erroneus videos not in the queued state from the queue" do
    @mocked_video_1.stub!(:queued?).and_return(false)
    
    Video.stub!(:next_job).and_return(@job_hashes)

    @mocked_video_1.should_receive(:delete_encoding_job).once.with(@job_hashes[0][:receipt])
    
    EncoderSingleton.schedule_jobs
  end
  
  it "should not start any new process threads if the job queue returns nothing" do
    Video.should_receive(:next_job).once.ordered.and_return([])
    
    Thread.should_not_receive(:new)
    EncoderSingleton.should_not_receive(:process_job)
    
    EncoderSingleton.schedule_jobs
  end
  
end

describe EncoderSingleton, "job processing" do
  before(:each) do
    # no reason to sit around waiting
    EncoderSingleton.stub!(:sleep)  
    @mocked_video_1 = stub_everything("mocked video 1")
    @mocked_video_2 = stub_everything("mocked video 2")
                   
    @job_hash_1 = {:video => @mocked_video_1, :receipt => "receipt 1"}
    @job_hash_2 = {:video => @mocked_video_2, :receipt => "receipt 2"}
                   
    # to_yaml was breaking the specs; stub_everything apparently doesn't REALLY "stub everything"
    @mocked_video_1.stub!(:to_yaml).and_return(@mocked_video_1)
    @mocked_video_2.stub!(:to_yaml).and_return(@mocked_video_2)
                   
    # stub this for now; mock it when needed
    ErrorSender.stub!(:log_and_email)
    
    # stub out the mutex unless it needs to be mocked
    EncoderSingleton.job_mutex.stub!(:synchronize).and_yield
    
    @mocked_logger = stub_everything()
    Merb.stub!(:logger).and_return(@mocked_logger)
  end
  
  it "should encode a video and then delete the job from the queue" do
    @mocked_video_1.should_receive(:encode).once.ordered
    @mocked_video_1.should_receive(:delete_encoding_job).once.ordered
    
    EncoderSingleton.process_job(@job_hash_1, 1234)
  end
  
  it "should not delete the job from the queue on an encode error" do
    @mocked_video_1.stub!(:encode).and_raise(Exception)
    @mocked_video_1.should_not_receive(:delete_encoding_job)
    
    EncoderSingleton.process_job(@job_hash_1, 1234)
  end
  
  it "should log an error on a failure" do
    @mocked_video_1.stub!(:encode).and_raise(Exception)
    
    ErrorSender.should_receive(:log_and_email).once
    
    EncoderSingleton.process_job(@job_hash_1, 1234)
  end
  
  it "should log a meta-error if normal error logging fails" do
    @mocked_video_1.stub!(:encode).and_raise(Exception)
    ErrorSender.stub!(:log_and_email).and_raise(Exception)
    
    @mocked_logger.should_receive(:error).once
    
    EncoderSingleton.process_job(@job_hash_1, 1234)
  end
  
  it "should safely decrement the active job count on finishing a job" do
    @mocked_video_1.should_receive(:encode).once.ordered
    @mocked_video_1.should_receive(:delete_encoding_job).once.ordered
    
    EncoderSingleton.job_mutex.should_receive(:synchronize).and_yield
    EncoderSingleton.should_receive(:dec_job_count).once.ordered
    
    EncoderSingleton.process_job(@job_hash_1, 1234)
  end
  
  it "should safely decrement the active job count when a job errors" do
    @mocked_video_1.should_receive(:encode).once.ordered.and_raise(Exception)
    
    EncoderSingleton.job_mutex.should_receive(:synchronize).and_yield
    EncoderSingleton.should_receive(:dec_job_count).once.ordered
    
    EncoderSingleton.process_job(@job_hash_1, 1234)
  end
end

describe EncoderSingleton, "concurrent job processing" do
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
    
    @mocked_logger = stub_everything()
    Merb.stub!(:logger).and_return(@mocked_logger)
  end
  
  it "should fetch an array of jobs and then process each, encoding and then deleteing from the job queue" do
    Video.should_receive(:next_job).once.ordered.with(Panda::Config[:max_pull_down]).and_return(@job_hashes)
    
    @mocked_video_1.should_receive(:encode).once.ordered
    @mocked_video_1.should_receive(:delete_encoding_job).once.ordered.with("receipt 1")
    
    @mocked_video_2.should_receive(:encode).once.ordered
    @mocked_video_2.should_receive(:delete_encoding_job).once.ordered.with("receipt 2")
    
    EncoderSingleton.process_jobs
  end
  
  it "should not try to encode anything if Video::next_job returns no jobs" do
    Video.should_receive(:next_job).once.ordered.and_return([])
    
    @mocked_video_1.should_not_receive(:encode)
    @mocked_video_1.should_not_receive(:delete_encoding_job)
    
    @mocked_video_2.should_not_receive(:encode)
    @mocked_video_2.should_not_receive(:delete_encoding_job)
    
    EncoderSingleton.process_jobs
  end
  
  it "should not delete the job from the queue if encoding fails" do
    Video.should_receive(:next_job).once.ordered.and_return(@job_hashes)
    ErrorSender.stub!(:log_and_email)
    
    @mocked_video_1.should_receive(:encode).once.ordered.and_raise(Exception)
    @mocked_video_1.should_not_receive(:delete_encoding_job)
    
    EncoderSingleton.process_jobs
  end
  
  it "should continue processing jobs if one fails" do
    Video.should_receive(:next_job).once.ordered.and_return(@job_hashes)
    ErrorSender.stub!(:log_and_email)
    
    @mocked_video_1.should_receive(:encode).once.ordered.and_raise(Exception)
    
    @mocked_video_2.should_receive(:encode).once.ordered
    @mocked_video_2.should_receive(:delete_encoding_job).once.ordered.with("receipt 2")
    
    EncoderSingleton.process_jobs
  end
  
  it "should log an error on a failure" do
    Video.should_receive(:next_job).once.ordered.and_return(@job_hashes)
    
    @mocked_video_1.should_receive(:encode).once.ordered.and_raise(Exception)
    ErrorSender.should_receive(:log_and_email).once.ordered
    
    EncoderSingleton.process_jobs
  end
  
  it "should log a meta-error if normal error logging fails" do
    Video.should_receive(:next_job).once.ordered.and_return(@job_hashes)
    
    @mocked_video_1.should_receive(:encode).once.ordered.and_raise(Exception)
    ErrorSender.should_receive(:log_and_email).once.ordered.and_raise(Exception)
    @mocked_logger.should_receive(:error).once.ordered
    
    EncoderSingleton.process_jobs
  end
end
require 'thread'

class EncoderSingleton
  @@job_count = 0
  @@job_mutex = Mutex.new
  
  def self.job_count
    @@job_count
  end
  
  def self.job_count=(amount)
    @@job_count = amount
  end
  
  def self.inc_job_count
    @@job_count += 1
  end
  
  def self.dec_job_count
    @@job_count -= 1
  end
  
  def self.job_mutex
    @@job_mutex
  end
  
  def self.schedule_jobs
    jobs = []
    
    @@job_mutex.synchronize do
      jobs = Video.next_job(Panda::Config[:max_pull_down] - @@job_count)
      
      jobs.each { EncoderSingleton.inc_job_count }
    end
    
    jobs.each do |job|
      if job[:video].queued?
        Thread.new(job) do |job|
          EncoderSingleton.process_job(job)
        end
      end
    end
  end
  
  def self.process_job(job)
    begin
      sleep 10
      video = job[:video]
      video.encode
      # will not send delete receipt back to sqs if encoding process errors
      video.delete_job(job[:receipt])
    rescue Exception => e
      begin
        ErrorSender.log_and_email("encoding error", "Error encoding #{video.key}

#{$!}

PARENT ATTRS

#{"="*60}\n#{video.parent_video.attributes.to_h.to_yaml}\n#{"="*60}

ENCODING ATTRS

#{"="*60}\n#{video.attributes.to_h.to_yaml}\n#{"="*60}")
      rescue Exception => meta_e
        Merb.logger.error "Error sending error using ErrorSender.log_and_email - very erroneous! (#{$!})"
      end
    ensure
      @@job_mutex.synchronize do
        EncoderSingleton.dec_job_count
      end
    end
  end
  
  # non-threaded
  def self.process_jobs
    jobs = Video.next_job(Panda::Config[:max_pull_down])
    
    jobs.each do |job|
      begin
        sleep 10
        video = job[:video]
        video.encode
        # will not send delete receipt back to sqs if encoding process errors
        video.delete_job(job[:receipt])
      rescue Exception => e
        begin
          ErrorSender.log_and_email("encoding error", "Error encoding #{video.key}

  #{$!}

  PARENT ATTRS

  #{"="*60}\n#{video.parent_video.attributes.to_h.to_yaml}\n#{"="*60}

  ENCODING ATTRS

  #{"="*60}\n#{video.attributes.to_h.to_yaml}\n#{"="*60}")
        rescue Exception => meta_e
          Merb.logger.error "Error sending error using ErrorSender.log_and_email - very erroneous! (#{$!})"
        end
      end
    end
  end
end
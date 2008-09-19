require 'thread'

class EncoderSingleton
  @@job_count = 0
  @@job_id = 1
  @@job_mutex = Mutex.new
  @@s3_mutex = Mutex.new
  
  def self.job_count
    @@job_count
  end
  
  def self.job_id
    @@job_id
  end
  
  def self.job_count=(amount)
    @@job_count = amount
  end
  
  def self.inc_job_count
    @@job_count += 1
    @@job_id += 1
  end
  
  def self.dec_job_count
    @@job_count -= 1
  end
  
  def self.job_mutex
    @@job_mutex
  end
  
  def self.s3_mutex
    @@s3_mutex
  end
  
  def self.schedule_jobs
    jobs = []
    
    jobs = Video.next_job(Panda::Config[:max_pull_down].to_i - job_count)
    Merb.logger.info "#{jobs.size} jobs taken from queue" unless jobs.empty?
    
    jobs.each do |job|
      Merb.logger.info "Evaluating encoding job from queue with ID #{job[:video].key}"
      if job[:video].queued?
        job_mutex.synchronize do
           EncoderSingleton.inc_job_count 
        end
        proc_id = (Kernel.rand * 100000).floor
        Thread.new(job) do |job|
          EncoderSingleton.process_job(job, proc_id)
        end
        Merb.logger.info "Video with ID #{job[:video].key} being encoded in separate thread with ID = #{proc_id}. job count incremented to #{job_count}"
      else
        Video.delete_encoding_job(job[:receipt])
        Merb.logger.info "Video with ID #{job[:video].key} pulled, but is not in correct state. Removing from queue."
      end
    end
  end
  
  def self.process_job(job, proc_id)
    begin
      Merb.logger.info "Encoder Thread #{proc_id}: starting; sleeping for a bit"
      sleep 10
      video = job[:video]
      Merb.logger.info "Encoder Thread #{proc_id}: calling video.encode"
      video.encode(s3_mutex, proc_id)
    rescue Exception => e
      Merb.logger.info "Encoder Thread #{proc_id}: ERROR during encoding"
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
      Video.delete_encoding_job(job[:receipt])
      job_mutex.synchronize do
        EncoderSingleton.dec_job_count
        Merb.logger.info "Encoder Thread #{proc_id}: thread finishing; job count decremented to #{job_count}"
      end
    end
  end
end
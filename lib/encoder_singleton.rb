class EncoderSingleton
  def self.process_jobs
    jobs = Video.next_job
    
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
class JobQueue
  def initialize
    @sqs = RightAws::SqsGen2Interface.new(Panda::Config[:access_key_id], Panda::Config[:secret_access_key])
    full_queue_name = "#{Panda::Config[:account_name].downcase.sub(/\s/, '_')}_job_queue"
    @url = @sqs.queue_url_by_name(full_queue_name)
    if @url.nil?
      # queue doesn't exist so make one with the correct name and settings
      @url = @sqs.create_queue(full_queue_name, Panda::Config[:default_timeout])
    end
  end
  
  def enqueue(video_object)
    @sqs.send_message(@url, video_object.key.to_s)
  end
  
  def dequeue(max)
    response = @sqs.receive_message(@url, max)
    if response.empty?
      return []
    else
      videos = []
      response.each do |message|
        video = Video.find(message["Body"])
        videos << {:video => video, :receipt => message["ReceiptHandle"]}
      end
      return videos
    end
  end
  
  def delete(receipt)
    @sqs.delete_message(@url, receipt)
  end
  
  def num_jobs()
    @sqs.get_queue_length(@url)
  end
  
  def get_settings()
    @sqs.get_queue_attributes(@url)
  end
end
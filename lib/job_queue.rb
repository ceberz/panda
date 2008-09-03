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
    @sqs.send_message(@url, video_object.id.to_s)
  end
  
  def dequeue
    response = @sqs.receive_message(@url, Panda::Config[:max_pull_down])
    if response.empty?
      return nil
    else
      video = Video.find(response.first["Body"])
      return {:video => video, :receipt => response.first["ReceiptHandle"]}
    end
  end
  
  def delete(receipt)
    @sqs.delete_message(@url, receipt)
  end
end
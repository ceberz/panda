require 'job_queue.rb'

class NotifyQueue < JobQueue
  def initialize
    @sqs = RightAws::SqsGen2Interface.new(Panda::Config[:access_key_id], Panda::Config[:secret_access_key])
    full_queue_name = "#{Panda::Config[:account_name].downcase.sub(/\s/, '_')}_notify_queue"
    @url = @sqs.queue_url_by_name(full_queue_name)
    if @url.nil?
      # queue doesn't exist so make one with the correct name and settings
      @url = @sqs.create_queue(full_queue_name, Panda::Config[:default_timeout])
    end
  end
end
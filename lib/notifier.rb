# merb -r "panda/lib/notifier.rb"

# How notifications work:
# Once a video has been encoded its next_notification field will be set to the current time. It will then be returned by Video.outstanding_notifications and picked up by the notifier, which will then call send_notification on its parent.
# A notification will be sent to the client with the full details for the parent and all of its encoding. The response will be checked for presence of the word 'success' and a 200 response. If both are are not returned an error will be logged, and the next_notification field set to a few seconds in the future. Further notifications will be sent until success is returned from the client.

Merb.logger.info 'Notifier awake!'

loop do
  sleep 3
  Merb.logger.debug "Checking for messages... #{Time.now}"
  if encodings = Video.outstanding_notifications
    encodings.each do |encoding|
      begin
        encoding.send_notification if encoding.time_to_send_notification?
      rescue
        Merb.logger.error "ERROR (#{$!.to_s}) sending notification for #{encoding.key}. Waiting #{encoding.notification_wait_period}s before trying again."
      end
      sleep 1
    end
  end
end
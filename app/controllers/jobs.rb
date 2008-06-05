class Jobs < Application
  provides :yaml
  before :require_internal_auth
  before :set_job, :only => [:done]
  
  # Called whenever an encoding is complete
  def done
    Rog.log :info, "Encoder##{@ec2_instance.id} sent internal request for completed job #{@job.id}"
    @job.result = params[:result] # Save the raw result for furture debugging or some such
    job_data = YAML.load(params[:result])
    @job.status = "done"
    @job.encoding_time = job_data[:encoding_time]
    @job.save
    
    # Update status of video and its encodings
    job_data[:video][:encodings].each {|e| Encoding.find(e[:id]).change_status(e[:status]) }
    @job.video.change_status(:done)
    @job.video.send_status
  end
  
  def next
    # Rog.log :info, "Encoder##{@ec2_instance.id}: Internal request for job from #{request.remote_ip}"
    # Rog.log :info, "EC2##{@ec2_instance.id}: Internal request for job"
    # Find the next job in the queue
    job = Job.find_next_job
    
    # Tell the instance to call again later if there's nothing todo
    unless job
      # Rog.log :info, "EC2##{@ec2_instance.id}: No jobs, telling the instance to call again later"
      return {:command => :wait}.to_yaml
    end
    
    # TODO: Shutdown or start a new instance depending on the size of the queue
    # return {:command => :shutdown} if it's the right thing to do

    # Assign to the ec2 instance that requested it and change state to assigned
    job.assign_to_ec2(@ec2_instance)
    Rog.log :info, "Assigning job#{job.id} to encoder Encoder##{@ec2_instance.id}"
    return {:job => job.job_response}.to_yaml
  end
  
private

  def set_job
    unless @job = Job.find(params[:id])
      throw :halt, render('', :status => 404)
    end
  end
end
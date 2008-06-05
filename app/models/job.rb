class Job < ActiveRecord::Base
  belongs_to :video
  belongs_to :ec2
  
  before_create :set_default_status
  
  def set_default_status
    self.status = 'queued'
  end
  
  def job_response
    {
      :id => self.id,
      :video => self.video.job_response
    }
  end
  
  def assign_to_ec2(ec2_instance)
    self.ec2_id = ec2_instance.id
    self.status = 'processing'
    self.save
    
    self.video.change_status(:processing)
    self.video.send_status
  end
  
  def self.find_next_job
    self.find(:first, :conditions => "status = 'queued'", :order => "created_at asc")
  end
end
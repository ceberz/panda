class Dashboard < Application
  before :require_login
  
  def index
    @recent_encodings = Video.recent_encodings
    @queued_encodings = Video.queued_encodings
    
    job_queue = EncodeQueue.new
    @num_jobs_in_queue = job_queue.num_jobs
    @queued_in_qb = Video.query("['status' = 'queued']").size
    @num_running_threads = EncoderSingleton.job_count
    render
  end
end
class Dashboard < Application
  before :require_login
  
  def index
    @recent_encodings = Video.recent_encodings
    @queued_encodings = Video.queued_encodings
    render
  end
end
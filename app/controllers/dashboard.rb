class Dashboard < Application
  before :require_login
  
  def index
    @recent_videos = Video.recent_videos
    render
  end
end
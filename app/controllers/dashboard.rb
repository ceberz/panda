class Dashboard < Application
  before :require_login
  
  def index
    @queued_videos = Video.queued_videos
    @recently_completed_videos = Video.recently_completed_videos
    render
  end
end
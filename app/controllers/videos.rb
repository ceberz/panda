class Videos < Application
  provides :html, :xml, :yaml # Allow before filters to accept all formats, which are then futher refined in each action
  before :require_login, :only => [:index, :show, :destroy, :new, :create, :add_to_queue, :jobs]
  before :set_video, :only => [:show, :destroy, :add_to_queue]
  before :set_video_with_nice_errors, :only => [:form, :done, :state]

  def index
    provides :html, :xml, :yaml
    # @videos = AWS::S3::Bucket.find('pandavision').objects
    @videos = Video.all
    
    case content_type
    when :html
      render
    when :xml
      {:videos => @videos.map {|v| v.show_response }}.to_simple_xml
    when :yaml
      {:videos => @videos.map {|v| v.show_response }}.to_yaml
    end
  end

  def show
    provides :html, :xml, :yaml
    
    case content_type
    when :html
      # TODO: use proper auth method
      @user = User.find(session[:user_key]) if session[:user_key]
      if @user
        if @video.status == "original"
          render :show_parent
        else
          render :show_encoding
        end
      else
        redirect("/login")
      end
    when :xml
      @video.show_response.to_simple_xml
    when :yaml
      @video.show_response.to_yaml
    end
  end
  
  # Use: HQ
  # Only used in the admin side to post to create and then forward to the form where the video is uploaded
  def new
    provides :html
    render :layout => :simple
  end
  
  def edit
    # TODO: Edit video action
  end
  
  def destroy
    @video.obliterate!
    redirect "/videos"
  end

  # Use: HQ, API
  def create
    provides :html, :xml, :yaml
    @video = Video.create
    @video.status = 'empty'
    @video.save
    Merb.logger.info "#{@video.key}: Created video"
    sleep 2

    case content_type
    when :html
      redirect "/videos/#{@video.key}/form"
      # redirect url(:controller => :videos, :action => :form, :id => @video.key)
    when :xml
      headers.merge!({'Location'=> "/videos/#{@video.key}"})
      @video.create_response.to_simple_xml
    when :yaml
      headers.merge!({'Location'=> "/videos/#{@video.key}"})
      @video.create_response.to_yaml
    end
  end
  
  def update
    # TODO: Update video action
  end
  
  # Use: HQ, API, iframe upload
  def form
    provides :html
    render :layout => :uploader
  end
  
  # Use: HQ, http/iframe upload
  def upload
    provides :html#, :xml, :yaml, :json
    
    begin
      raise Video::NoFileSubmitted if !params[:file] || params[:file].blank?
      @video = Video.find(params[:id])
      @video.filename = @video.key + File.extname(params[:file][:filename])
      FileUtils.mv params[:file][:tempfile].path, @video.tmp_filepath
      @video.original_filename = params[:file][:filename].split("\\\\").last # Split out any directory path Windows adds in
      @video.process
      @video.status = "original"
      @video.save
    rescue Amazon::SDB::RecordNotFoundError # No empty video object exists
      self.status = 404
      render_error($!.to_s.gsub(/Amazon::SDB::/,""))
    rescue Video::NotValid # Video object is not empty. It's likely a video has already been uploaded for this object.
      self.status = 404
      render_error($!.to_s.gsub(/Video::/,""))
    rescue Video::VideoError
      self.status = 500
      render_error($!.to_s.gsub(/Video::/,""))
    rescue
      self.status = 500
      render_error("InternalServerError") # TODO: Use this generic error in production
    else
      case content_type
      when :html  
        # Special internal Panda case: textarea hack to get around the fact that the form is submitted with a hidden iframe and thus the response is rendered in the iframe
        if params[:iframe] == "true"
          "<textarea>" + {:location => @video.upload_redirect_url}.to_json + "</textarea>"
        else
          redirect @video.upload_redirect_url
        end
      end
    end
  end
  
  # NOTE: Default done page people see after successfully uploading a video. Edit init.rb and set upload_redirect_url to be somewhere else.
  def done
    provides :html
    render :layout => :uploader
  end
  
  # NOTE: This action should only be used for local testing, and in production should be an action in the app you're integrating Panda into. Be sure to set the state_update_url setting in your init.rb
  # TODO: Only allow from localhost
  def state
    Merb.logger.info(params.to_yaml)
  end
  
  def add_to_queue
    @video.add_to_queue
    redirect "/videos/#{@video.key}"
  end
  
  def jobs
    job_queue = JobQueue.new
    @num_jobs_in_queue = job_queue.num_jobs
    @queued_in_qb = Video.query("['status' = 'queued']")
    @num_running_threads = EncoderSingleton.job_count
  end
  
private

  def render_error(msg)
    Merb.logger.error "#{params[:id]}: (500 returned to client) #{msg}"

    case content_type
    when :html
      if params[:iframe] == "true"
        "<textarea>" + {:error => msg}.to_json + "</textarea>"
      else
        @exception = msg
        render(:template => "/exceptions/video_exception", :layout => false) # TODO: Why is :action setting 404 instead of 500?!?!
      end
    when :xml
      {:error => msg}.to_simple_xml
    when :yaml
      {:error => msg}.to_yaml
    end
  end
  
  def set_video
    # Throws Amazon::SDB::RecordNotFoundError if video cannot be found
    @video = Video.find(params[:id])
  end
  
  def set_video_with_nice_errors
    begin
      @video = Video.find(params[:id])
    rescue Amazon::SDB::RecordNotFoundError
      self.status = 404
      throw :halt, render_error($!.to_s.gsub(/Amazon::SDB::/,""))
    end
  end
end
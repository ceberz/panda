class Videos < Application
  provides :html, :xml, :yaml # Allow before filters to accept all formats, which are then futher refined in each action
  before :require_login, :only => [:index, :create]
  # before :require_internal_auth, :only => [:valid,:uploaded]
  before :set_video, :only => [:show, :valid, :uploaded]
  
  def index
    provides :html, :xml, :yaml
    # @videos = AWS::S3::Bucket.find('pandavision').objects
    @videos = @account.videos.find(:all, :order => "created_at desc")
    
    case content_type
    when :html
      render :layout => :accounts
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
      @account = Account.find(session[:account_id]) if session[:account_id]
      if @account
        render :layout => :accounts
      else
        redirect("/login")
      end
    when :xml
      @video.show_response.to_simple_xml
    when :yaml
      @video.show_response.to_yaml
    end
  end
  
  # Just for our testing
  def new
    provides :html
    render :layout => "simple"
  end

  def create
    provides :html, :xml, :yaml
    @video = @account.videos.create
    Rog.log :info, "#{@video.token}: Created video"

    case content_type
    when :html
      redirect @video.upload_form_url
    when :xml
      headers.merge!({'Location'=> "/videos/#{@video.token}"})
      @video.create_response.to_simple_xml
    when :yaml
      headers.merge!({'Location'=> "/videos/#{@video.token}"})
      puts @video.create_response.to_yaml
      @video.create_response.to_yaml
    end
  end

  # Internal API
  
  def valid
    provides :yaml
    Rog.log :info, "#{params[:id]}: Internal request for validity of video"
    if @video.empty?
      Rog.log :info, "#{params[:id]}: Response: 200"
      render('', :status => 200)
    else
      Rog.log :info, "#{params[:id]}: Response: 404"
      render('', :status => 404)
    end
  end
  
  # Called when an uploader instance receives a new file
  # First we check that there is a video id with no previously uploaded file
  # If we were expecting this file, we create the jobs to encode it to varoius formats
  # Then we reply with the url that the customer wants user's to be redirected to after uploading a video
  def uploaded
    provides :yaml
    Rog.log :info, "#{params[:id]}: Internal request to confirm upload for video"
    # Don't allow files to be uploaded to a video id more than once
    unless @video.empty?
      Rog.log :info, "#{params[:id]}: Whoops, this doesn't look like a valid upload"
      Rog.log :info, "#{params[:id]}: Response: 404"
      render('', :status => 404) and return
    end
    
    @video.filename = params[:filename]
    @video.save_metadata(YAML.load(params[:metadata]))
    @video.save

    @video.add_encodings
    job = @video.add_to_queue
    Rog.log :info, "#{params[:id]}: Video added to queue (job id: #{job.id})"

    # Tell the uploader where to redirect the client to
    headers.merge!({'Location'=> @video.account.upload_redirect_url_or_default})
    Rog.log :info, "#{params[:id]}: Response: 200"
    render('', :status => 200)
  end
end
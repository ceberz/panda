class Accounts < Application
  provides :html
  before :require_login, :only => [:dashboard, :show, :edit, :update]
  
  def new
    @account = Account.new
    @account.email = params[:email] if params[:email]
    
    if request.post?
      if invite = Invite.find(:first, :conditions => ["email = ? and account_id IS NULL and approved IS NOT NULL",params[:account][:email]])
        @account = Account.new(params[:account])
        if @account.save!
          invite.update_attribute(:account_id, @account.id)
          session[:account_id] = @account.id
          redirect "/"
        end
      else
        render :text => "No invite for that email address."
      end
    else
      render :layout => "auth"
    end
  end
  
  def dashboard
    @queued_videos = @account.queued_videos
    @recently_completed_videos = @account.recently_completed_videos
    render
  end
  
  def show
    render
  end
  
  def edit
    render
  end
  
  def update
    @account.update_attribute(:name, params[:account][:name])
    @account.update_attribute(:email, params[:account][:email])
    @account.update_attribute(:upload_redirect_url, params[:account][:upload_redirect_url])
    @account.update_attribute(:state_update_url, params[:account][:state_update_url])
    
    unless params[:account][:password].blank?
      @account.password = params[:account][:password]
      @account.password_confirmation = params[:account][:password_confirmation]
      @account.save!
    end
    
    redirect "/accounts"
  end
end
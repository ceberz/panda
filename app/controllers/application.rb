# all your other controllers should inherit from this one to share code.
class Application < Merb::Controller
  provides :html
  # Auth plugin
  attr_accessor :account
  
  def index
    redirect "/dashboard"
  end

private

  def require_login
    case (params[:format] || "html")
    when "html"
      Merb.logger.info("AUTH DEBUG: session[:account_id]: #{session[:account_id]}")
      @account = Account.find(session[:account_id]) if session[:account_id]
      Merb.logger.info("AUTH DEBUG: @account:")
      Merb.logger.info(@account.to_yaml)
      throw :halt, redirect("/login") unless @account
    when "xml", "yaml"
      @account = Account.find_by_token(params[:account_key])
      throw :halt, render('', :status => 401) unless @account
    else
      throw :halt, render('', :status => 401)
    end
  end
  
  # Ensure the request is coming from one of our ec2 instances
  def require_internal_auth
    # if Merb.environment == "development"
    #   @ec2_instance = Ec2.find(:first, :conditions => {:amazon_id => "test"})
    # end
    unless @ec2_instance = Ec2.find(:first, :conditions => {:address => request.remote_ip})
      throw :halt, render('', :status => 401)
    end
    # Rog.log :info, "Identified Encoder##{@ec2_instance.id} with IP #{request.remote_ip}"
  end

  def set_video
    unless @video = Video.find_by_token(params[:id])
      throw :halt, render('', :status => 404)
    end
  end
end  
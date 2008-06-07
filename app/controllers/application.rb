# all your other controllers should inherit from this one to share code.
class Application < Merb::Controller
  provides :html
  # Auth plugin
  attr_accessor :user
  
  def index
    redirect "/dashboard"
  end

private

  def require_login
    case (params[:format] || "html")
    when "html"
      @user = User.find(session[:user_key]) if session[:user_key]
      throw :halt, redirect("/login") unless @user
    when "xml", "yaml"
      throw :halt, render('', :status => 401) unless params[:account_key] == Panda::Config[:api_key]
    else
      throw :halt, render('', :status => 401)
    end
  end
  
  def set_video
    unless @video = Video.find(params[:id])
      throw :halt, render('', :status => 404)
    end
  end
end  
class Auth < Application
  provides :html
  # Auth plugin
  
  def login
    @account = Account.new
    
    if request.post?
      Merb.logger.info("AUTH DEBUG: Got post")
      Merb.logger.info(params[:account].to_yaml)
      
      if @account = Account.authenticate(params[:account])
        Merb.logger.info("AUTH DEBUG: Account.authenticate returned valid account")
        session[:account_id] = @account.id
        Merb.logger.info("AUTH DEBUG: session[:account_id] = #{@account.id}")
        redirect "/"
      else
        @account = Account.new(:login => params[:account][:login])
        @notice = "Your username or password was incorrect."
        Merb.logger.info("AUTH DEBUG: Invalid auth")
      end
    end
    
    render
  end
  
  def logout
    session[:account_id] = nil
    redirect "/"
  end
end
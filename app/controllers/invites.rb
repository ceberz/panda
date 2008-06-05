class Invites < Application
  def create
    @invite = Invite.new(:email => params[:invite][:email])
    
    return render :text => "Email already invited" if Invite.find_by_email(@invite.email)
    
    if @invite.save!
      send_mail(InviteMailer, :notification, {
                  :from => EMAIL_SENDER,
                  :to => @invite.email,
                  :subject => "Thanks for signing up for the Panda beta"
                })
      redirect "http://pandastream.com/thanks"
    else
      return render :text => "Invalid email"
    end
  end
end
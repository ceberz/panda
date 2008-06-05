class InviteMailer < Merb::MailController
  def notification
    render_mail
  end
  def approved
    render_mail
  end
end
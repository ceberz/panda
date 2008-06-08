class Profiles < Application
  # TODO: Profiles API
  provides :html
  before :require_login
  before :set_profile, :only => [:show, :edit, :delete, :create, :update]
  
  def index
    @profiles = Profile.query
    render
  end

  def show
    
    render
  end

  def new
    render
  end

  def edit
    render
  end

  def delete
    render
  end

  def create
    render
  end

  def update
    render
  end

  def destroy
    render
  end
  
private

  def set_profile
    unless @profile = Profile.find(params[:id])
      throw :halt, render('', :status => 404)
    end
  end
end

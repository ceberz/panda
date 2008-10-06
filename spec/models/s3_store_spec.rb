require File.join( File.dirname(__FILE__), "..", "spec_helper" )

describe S3Store do
  
  before :each do
    @store = S3Store.new
    
    @fp = mock(File)
    @fp.stub!(:write)
  end
  
  describe "set" do
    
    it "should upload to s3" do
      File.should_receive(:open).
        with('/tmp/abc.mov').and_return(:fp)
      S3VideoObject.should_receive(:store).
        with('abc.mov', :fp, :access => :public_read).and_return(true)
      
      @store.set('abc.mov', '/tmp/abc.mov')
    end
    
    it "should retry uploading up to 6 times and raise exception on fail" do
      File.should_receive(:open).exactly(6).times.
        with('/tmp/abc.mov').and_return(:fp)
      S3VideoObject.should_receive(:store).exactly(6).times.
        with('abc.mov', :fp, :access => :public_read).
        and_raise(AWS::S3::S3Exception)
      
      lambda {
        @store.set('abc.mov', '/tmp/abc.mov')
      }.should raise_error(AWS::S3::S3Exception)
    end
    
  end
  
  describe "get" do
    
    it "should fetch from s3" do
      File.should_receive(:open).with('/tmp/abc.mov', 'w').and_yield(@fp)
      S3VideoObject.should_receive(:stream).with('abc.mov').and_yield('chunk')
      
      @store.get('abc.mov', '/tmp/abc.mov').should be_true
    end

    it "should retry fetching up to 6 times and raise exception on fail" do
      File.should_receive(:open).exactly(6).times.
        with('/tmp/abc.mov', 'w').and_yield(@fp)
      S3VideoObject.should_receive(:stream).exactly(6).times.
        with('abc.mov').and_raise(AWS::S3::S3Exception)

      lambda {
        @store.get('abc.mov', '/tmp/abc.mov')
      }.should raise_error(AWS::S3::S3Exception)
    end
    
  end
  
  describe "delete" do
    it "should delete from S3"
    
    it "should retry deleting up to 6 times and raise exception on fail"
  end
  
  describe "url" do
    it "should convert the S3 key into a url" do
      @store.url('foo.mov').
        should == "http://s3.amazonaws.com/myvideosbucket2/foo.mov"
    end
  end
  
end

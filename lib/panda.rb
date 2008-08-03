module Panda
  
  class Setup
    class << self
      def create_s3_bucket(name)
        AWS::S3::Bucket.create(name)
      end
      
      def create_sqs_queue(name)
        SQS.create_queue(name)
      end
      
      def create_sdb_domain(name)
       SimpleDB::Base.connection.create_domain(name)
      end
    end
  end

  class Config
    class << self
      def defaults
        @defaults ||= {
          :account_name           => "My Panda Account",
          :api_key                => nil,
          :notification_email     => nil,
          :upload_redirect_url    => "http://127.0.0.1:3000/videos/$1/done",
          :state_update_url       => "http://127.0.0.1:3000/videos/$1/status",
          :videos_domain          => nil,
          :storage                => :filesystem, # or :s3 TODO: implement
          :thumbnail_height_constrain => 126,
          :notification_frequency => 3
        }
      end
      
      def use
        @configuration ||= {}
        yield @configuration
      end

      def [](key)
        @configuration[key] || defaults[key]
      end
      
      def []=(key,val)
        @configuration[key] = val
      end
    end
  end
end
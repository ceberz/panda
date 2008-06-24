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

      # ==== Returns
      # Hash:: The defaults for the config.
      def defaults
        @defaults ||= {
          :account_name           => "My Panda Account",
          :api_key                => nil,
          :upload_redirect_url    => "http://127.0.0.1:3000/videos/$1/done",
          :state_update_url       => "http://127.0.0.1:3000/videos/$1/status",
          :videos_domain          => nil,
          :storage                => :filesystem # or :s3 TODO: implement
        }
      end

      # Yields the configuration.
      #
      # ==== Block parameters
      # c<Hash>:: The configuration parameters.
      #
      # ==== Examples
      #   Merb::Config.use do |config|
      #     config[:exception_details] = false
      #   end
      def use
        @configuration ||= {}
        yield @configuration
      end

      # ==== Parameters
      # key<Object>:: The key to check.
      #
      # ==== Returns
      # Boolean:: True if the key exists in the config.
      def key?(key)
        @configuration.key?(key)
      end

      # ==== Parameters
      # key<Object>:: The key to retrieve the parameter for.
      #
      # ==== Returns
      # Object:: The value of the configuration parameter.
      def [](key)
        (@configuration||={})[key]
      end

      # ==== Parameters
      # key<Object>:: The key to set the parameter for.
      # val<Object>:: The value of the parameter.
      def []=(key,val)
        @configuration[key] = val
      end
    end
  end
end
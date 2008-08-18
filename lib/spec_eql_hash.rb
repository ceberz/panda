module Spec
  module Matchers
  
    class EqlHash #:nodoc:
      def initialize(expected)
        @expected = expected
      end
  
      def matches?(actual)
        @actual = actual
        @missmatches = []
        
        # Both hashes have the key, but the values are different
        @expected.each do |k,v|
          unless actual[k] == v
            @missmatches << "#{k} key expected value of #{v} #{actual[k] ? ", got #{actual[k]}" : "but it wasn't in the actual hash"}"
          end
        end
        
        # The actual hash has extra keys that weren't expected
        (actual.keys - @expected.keys).each do |k|
          @missmatches << "#{k} key wasn't expected but is in the actual hash, with a value of #{actual[k]}"
        end
        
        @missmatches.empty?
      end

      def failure_message
        return "expected #{@expected.inspect}, got #{@actual.inspect} (using .eql?)\n\n#{@missmatches.join("\n")}", @expected, @actual
      end
      
      def negative_failure_message
        return "expected #{@actual.inspect} not to equal #{@expected.inspect} (using .eql?)", @expected, @actual
      end

      def description
        "eql #{@expected.inspect}"
      end
    end
    
    # :call-seq:
    #   should eql_hash(expected)
    #
    # Passes if actual and expected are of equal value, but not necessarily the same object.
    #
    # See http://www.ruby-doc.org/core/classes/Object.html#M001057 for more information about equality in Ruby.
    #
    # == Examples
    #
    #   {:a => 1}.should eql({:a => 1})
    def eql_hash(expected)
      Matchers::EqlHash.new(expected)
    end
  end
end

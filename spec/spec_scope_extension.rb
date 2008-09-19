require 'spec'
require 'spec/mocks'

module Spec
  module Mocks
    class ErrorGenerator
      def raise_incorrect_scope_error(sym, expected, actual)
        def gen_scope_string(list, sym)
          return sym.to_s if list.empty?
          return "#{list.shift}: { #{gen_scope_string(list, sym)} }"
        end
        actual_string = actual.empty? ? "no generated scope" : gen_scope_string(actual, sym)
        __raise "#{intro} expected :#{sym} to be called within the scope of #{gen_scope_string(expected, sym)}, but received it within #{actual_string}"
      end
    end
    
    class Space
          def push_scope(scope)
            scope_stack.push(scope)
          end
          
          def pop_scope
            scope_stack.pop
          end
          
          def get_scope_stack
            scope_stack
          end
          
          alias_method :original_reset_all, :reset_all
          def reset_all
            @scope_stack.clear unless @scope_stack.nil?
            original_reset_all
          end
          
        private
        
          def scope_stack
            @scope_stack ||= []
          end
        end

    class BaseExpectation
      alias_method :original_initialize, :initialize
      def initialize(error_generator, expectation_ordering, expected_from, sym, method_block, expected_received_count=1, opts={})
        @expected_scope_stack = []
        @stubbed_scope = nil 
        original_initialize(error_generator, expectation_ordering, expected_from, sym, method_block, expected_received_count, opts)
      end 
      
      def inside_scope(obj)
        @expected_scope_stack.unshift(obj)
        self
      end
      
      def with_scope(obj)
        @stubbed_scope = obj
        self
      end
      
      alias_method :original_invoke_with_yield, :invoke_with_yield
      def invoke_with_yield(block)
        begin
          $rspec_mocks.push_scope(@stubbed_scope) unless @stubbed_scope.nil?
          value = nil
          value = original_invoke_with_yield(block)
        rescue
          raise
        ensure
          $rspec_mocks.pop_scope unless @stubbed_scope.nil?
          value
        end
      end
      
      alias_method :original_invoke, :invoke
      def invoke(args, block)
        unless @expected_scope_stack.empty? or $rspec_mocks.get_scope_stack == @expected_scope_stack
          @error_generator.raise_incorrect_scope_error(@sym, @expected_scope_stack, $rspec_mocks.get_scope_stack) 
        end
        original_invoke(args, block)
      end
    end
  end
end
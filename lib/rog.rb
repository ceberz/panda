# == Synopsis
#
# Simple remote debug class 
#
# == Author
# Stefan Saasen s@juretta.com
#
# == Copyright
# Copyright (c) 2005 juretta.com Stefan Saasen
# Licensed under the same terms as Ruby.
# == Version
# Version 0.1 ($Id: logger.rb 5 2006-01-01 12:51:04Z stefan $)

require 'socket'
require 'singleton'
require 'timeout' 

class Rog
  include Singleton
  cattr_writer :port, :host, :prefix
  attr :session
  
  def self.log(level, msg)
    begin
	 Timeout::timeout(1) do 
      @session = TCPSocket.new(@@host, @@port)
      @session.puts Time.new.strftime("%Y-%m-%d %H:%M:%S") + \
      " " + "[" + level.to_s.upcase + "] #{@@prefix}: " + msg + "\n"
      @session.close  
    end
	 rescue => e	
	   return false
	 end
	 true
  end
end
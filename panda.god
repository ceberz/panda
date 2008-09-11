God.watch do |w|
  w.name = "panda"
  current_path  = "/usr/local/www/panda-alt/panda"
  port = 4001
  w.start = "/bin/bash -c 'cd #{current_path}; merb -d -p #{port} -e production'"
  w.stop = "/bin/bash -c 'cd #{current_path}; merb -k #{port}'"
  w.pid_file = File.join(current_path, "log/merb.#{port}.pid")
  w.behavior(:clean_pid_file)
  w.start_grace = 10.seconds
  w.restart_grace = 10.seconds
  
  w.start_if do |start|
    start.condition(:process_running) do |c|
      c.interval = 10.seconds
      c.running = false
      c.notify = 'admin'
    end
  end
  
  w.restart_if do |restart|
    # Restart if not returning http success
    restart.condition(:http_response_code) do |c|
      c.interval = 5.seconds
      c.host = '127.0.0.1'
      c.port = port
      c.path = '/login'
      c.code_is_not = 200
      c.timeout = 10.seconds
      c.times = [2, 3] # 2 out of 3 intervals
    end
  end
end

God.watch do |w|
  w.name = "encoder"
  current_path  = "/usr/local/www/panda-alt/panda"
  port = 4091
  w.start = "/bin/bash -c 'cd #{current_path}; merb -r lib/encoder.rb -d -p #{port} -e encoder'"
  w.stop = "/bin/bash -c 'cd #{current_path}; merb -k #{port}'"
  w.pid_file = File.join(current_path, "log/merb.#{port}.pid")
  w.behavior(:clean_pid_file)
  w.start_grace = 10.seconds
  w.restart_grace = 10.seconds
  
  w.start_if do |start|
    start.condition(:process_running) do |c|
      c.interval = 10.seconds
      c.running = false
      c.notify = 'admin'
    end
  end
end

God.watch do |w|
  w.name = "notifier"
  current_path  = "/usr/local/www/panda-alt/panda"
  port = 5091
  w.start = "/bin/bash -c 'cd #{current_path}; merb -r lib/notifier.rb -d -p #{port} -e notifier'"
  w.stop = "/bin/bash -c 'cd #{current_path}; merb -k #{port}'"
  w.pid_file = File.join(current_path, "log/merb.#{port}.pid")
  w.behavior(:clean_pid_file)
  w.start_grace = 10.seconds
  w.restart_grace = 10.seconds
  
  w.start_if do |start|
    start.condition(:process_running) do |c|
      c.interval = 10.seconds
      c.running = false
      c.notify = 'admin'
  	end
	end
end

God::Contacts::Email.message_settings = {
  :from => 'admin@localhost'
}

God::Contacts::Email.server_settings = {
  :address => "localhost",
  :port => 25,
  :domain => "pandastream.com"
  # :authentication => :plain,
  # :user_name => "john",
  # :password => "s3kr3ts"
}

God.contact(:email) do |c|
  c.name = 'admin'
  c.email = 'admin@localhost'
end
#######################################################
#
# demo-irb-server.rb (by Scott Moyer)
# 
# Creates a webrick server to allow you to edit the 
# scripts on the device from your browser. You can also
# send arbitrary code to execute on the device. 
#
#######################################################

require 'ruboto/activity'
require 'ruboto/widget'
require "ruboto/util/stack"
require 'ruboto/service'

SERVER_PORT = 8080

$main_binding = self.instance_eval{binding}

$default_exception_handler = proc do |t, e|
                               android.util.Log.e "Ruboto", e.to_s
                               e.stack_trace.each{|i| android.util.Log.e "Ruboto", i.to_s}
                             end

#####################################################

ruboto_import_widgets :LinearLayout, :TextView, :ToggleButton

$irb.start_ruboto_activity do
  attr_reader :ruboto_java_instance

  def on_create(bundle)
    super
    
    @setting_toggle_state = false

    $ui_thread = java.lang.Thread.currentThread
    $ui_thread.setUncaughtExceptionHandler($default_exception_handler)
    $irb_activity = self

    setContentView(
      linear_layout(:orientation => :vertical) do
        @start_button = toggle_button :enabled => false, 
                          :layout => {:width= => :wrap_content}, 
                          :on_click_listener => (proc{$server.toggle unless @setting_toggle_state})
        @status_text = text_view :text => "Initializing..."
      end
    )
  end

  def set_status(status_text, button_enabled=@start_button.enabled?)
    @start_button.enabled = button_enabled
    @status_text.text = status_text
    @setting_toggle_state = true
    @start_button.checked = $server.running?
    @setting_toggle_state = false
  end

  def start
    @start_button.performClick unless $server.running?
  end

  def stop
    @start_button.performClick if $server.running?
  end
end

#####################################################

Thread.with_large_stack do
  java.lang.Thread.currentThread.setUncaughtExceptionHandler($default_exception_handler)

  sleep 0.5

  require 'stringio'
require 'webrick'
require 'webrick/httpproxy'
require 'pathname'
require 'erb'
require 'pp'
require 'open-uri'

def target_uri?(uri)
  hst = uri.to_s
  hst =~ %r`http\:\/\/(gbf.*|game.*)(\.mbga|\.granbluefantasy)\.jp`
end

def cache_path(uri)
  filename = uri.to_s.sub(/http\:\/\/(gbf.*|game.*)(\.mbga\.jp|\.granbluefantasy\.jp)/, "")
  Pathname.new "../proxy/cache/#{ ERB::Util.url_encode filename }"
end

def target_content?(res)
  res['content-type'] =~ /(image|audio)/
end

def valid_content?(res)
  res.body
end

  class Server

$handler = proc do |req, res|
  if target_uri?(req.request_uri) && target_content?(res) && valid_content?(res)
    cache_path = cache_path(req.request_uri)
#	if !File.exists? cache_path
#	open(cache_path, 'wb') do |fo|
#	  fo.print open(req.unparsed_uri.gsub(/\?.*$/, "")).read
#    end
	File.write(cache_path, res.body) unless File.exists? cache_path
    status += "\ncache created: #{ req.unparsed_uri }"
	res.body = File.read cache_path
    raise WEBrick::HTTPStatus::OK
#	end
  end
end
$callback = proc do |req, res|
  cache_path = cache_path(req.request_uri)
  if target_uri?(req.request_uri) && File.exists?(cache_path)
	res["Access-Control-Allow-Origin"] = "*"
	res.body = File.read cache_path
	res.filename = cache_path
    status += "\ncache found: #{ req.unparsed_uri }"
    raise WEBrick::HTTPStatus::OK
  end
end

    def self.wifi_connected?
      ip_address != "localhost"
    end

    def self.ip_address
      ip = "localhost" 
    end
  
    def initialize(port)
      @port = port
    end
    
    def running?
      not @server.nil?
    end
    
    def __start
      title = "IRB server running on #{Server.ip_address}:8080"
      text = "Rerun the script to stop the server."
      ticker = "IRB server running on #{Server.ip_address}:8080"
      icon = android.R::drawable::stat_sys_upload

      notification = android.app.Notification.new(icon, ticker, java.lang.System.currentTimeMillis)
      intent = android.content.Intent.new
      intent.setAction("org.ruboto.intent.action.LAUNCH_SCRIPT")
      intent.addCategory("android.intent.category.DEFAULT")
      intent.putExtra("org.ruboto.extra.SCRIPT_NAME", "android-app.rb")
      pending = android.app.PendingIntent.getActivity($irb_activity.ruboto_java_instance, 0, intent, 0)
      notification.setLatestEventInfo($irb_activity.getApplicationContext, title, text, pending)
      $irb_service.startForeground(1, notification)

      @server.start
      @after_stop.call if @after_stop
    end

    def start
      unless @server
        @before_start.call if @before_start

        Thread.with_large_stack do 
          java.lang.Thread.currentThread.setUncaughtExceptionHandler($default_exception_handler)
          
          #@server = WEBrick::HTTPServer.new(:Port => @port, :DocumentRoot => Dir.pwd, :AccessLog => [])
		  @server = WEBrick::HTTPProxyServer.new(:BindAddress => '127.0.0.1', :Port => 8080, :AccessLog => [], :ProxyVia => false, :ProxyContentHandler => $handler, :RequestCallback => $callback)

          @after_start.call if @after_start
          $irb_activity.start_ruboto_service do
            def on_create
              super
            end

            def on_start_command(intent, flags, startId)
              super
              $irb_service = self
              Thread.with_large_stack do 
                java.lang.Thread.currentThread.setUncaughtExceptionHandler($default_exception_handler)
                $server.__start
              end        
              
              @ruboto_java_instance.class::START_NOT_STICKY
            end
          end
        end
      end
    end

    def stop
      if @server
        @before_stop.call if @before_stop

        @server.shutdown
        @server = nil
        $irb_activity.stop_service android.content.Intent.new($irb_activity.ruboto_java_instance, RubotoService.java_class)
        $irb_service = nil
      end
    end
    
    def toggle
      running? ? stop : start
    end

    def before_start &block
      @before_start = block
    end
    
    def after_start &block
      @after_start = block
    end

    def before_stop &block
      @before_stop = block
    end
    
    def after_stop &block
      @after_stop = block
    end
  end

#####################################################

  unless $server
    $server = Server.new(SERVER_PORT)
  
    $server.before_start do
      $irb_activity.runOnUiThread(proc{$irb_activity.set_status("Server starting...", false)})
    end
  
    $server.after_start do
      status = "Server started! Your browser must be properly configured for this to work. Set your browser's proxy to localhost, port 8080."
      status += "\n\nOr use 'http://#{Server.ip_address}:8080'" if Server.wifi_connected?
      $irb_activity.runOnUiThread(proc{$irb_activity.set_status(status, true)})
    end
  
    $server.before_stop do
      $irb_activity.runOnUiThread(proc{$irb_activity.set_status("Server shutting down...", false)})
    end

    $server.after_stop do
      $irb_activity.runOnUiThread(proc{$irb_activity.set_status("Press to start the server", true)})
      $irb_activity.getSystemService(android.content.Context::NOTIFICATION_SERVICE).cancel_all
    end
  end
  
  $irb_activity.runOnUiThread(proc{$irb_activity.set_status($server.running? ? "Server already running" : "Press to start a server", true)})
  $irb_activity.runOnUiThread(proc{$irb_activity.start})
end



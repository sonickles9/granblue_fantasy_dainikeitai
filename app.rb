# encoding: utf-8

require 'bundler'
Bundler.require

require 'webrick'
require 'webrick/httpproxy'
require 'pathname'
require 'erb'
require 'pp'
require 'open-uri'

def target_uri? uri
  hst = uri.to_s
  hst =~ %r`http\:\/\/(gbf.*|game.*)(\.mbga|\.granbluefantasy)\.jp`
end

def target_content? res
  res['content-type'] =~ /(image|audio)/
end

def valid_content? res
  res.body
end

def cache_path uri
  filename = uri.to_s.sub(/http\:\/\/(gbf.*|game.*)(\.mbga\.jp|\.granbluefantasy\.jp)/, "")
  Pathname.new "./cache/#{ ERB::Util.url_encode filename }"
end


def h str, color
  @h ||= HighLine.new
  @h.color str, color
end

handler = ->(req, res) {
  if target_uri?(req.request_uri) && target_content?(res) && valid_content?(res)
    cache_path = cache_path req.request_uri
#	if !File.exists? cache_path
#	open(cache_path, 'wb') do |fo|
#	  fo.print open(req.unparsed_uri.gsub(/\?.*$/, "")).read
#    end
	File.write(cache_path, res.body) unless File.exists? cache_path
	puts h "cache created: #{ req.unparsed_uri }", :blue
	res.body = File.read cache_path
    raise WEBrick::HTTPStatus::OK
#	end
  end
}

callback = ->(req, res) {
  cache_path = cache_path req.request_uri
  if target_uri?(req.request_uri) && File.exists?(cache_path)
	res["Access-Control-Allow-Origin"] = "*"
	res.body = File.read cache_path
	res.filename = cache_path
    puts h "cache found: #{ req.unparsed_uri }", :green
    raise WEBrick::HTTPStatus::OK
  end
}

s = WEBrick::HTTPProxyServer.new(
  BindAddress: '127.0.0.1',
  Port: 8080,
  Logger: WEBrick::Log::new(nil, 0),
  AccessLog: WEBrick::Log.new(nil, 0),
  ProxyVia: false,
  ProxyContentHandler: handler,
  RequestCallback: callback
)

Signal.trap(:INT) { s.shutdown }
Signal.trap(:TERM) { s.shutdown }

s.start

puts :hi


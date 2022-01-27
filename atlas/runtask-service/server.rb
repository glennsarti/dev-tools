require 'webrick'
require 'net/http'
require 'json'

# Docker command to run seperately
# docker run -it --publish "28080:8080" --mount "type=bind,source=$(pwd)/tmp/local-runtask/server.rb,target=/tmp/server.rb" ruby:2.7.4 ruby /tmp/server.rb

$pending_jobs = []
$exit_now = false

def respond_to(run_task)
  $server.logger.info("Processing request for #{run_task.parsed_body['task_result_id']}...")
  uri = URI(run_task.parsed_body['task_result_callback_url'])
  is_ssl = uri.scheme == 'https'

  Net::HTTP.start(uri.host, uri.port, :use_ssl => is_ssl) do |http|
    request = Net::HTTP::Patch.new uri

    resp_hash = {
      data: {
        type: 'task-results',
        attributes: {
          status: "#{run_task.status}",
          message: "#{run_task.message}",
          url: "#{run_task.parsed_body['run_app_url']}"
        }
      }
    }

    request.body = resp_hash.to_json
    request['Content-Type'] = 'application/vnd.api+json'
    request['Authorization'] = "Bearer #{run_task.parsed_body['access_token']}"


    $server.logger.info("Sending PATCH request to #{uri.to_s}: #{request.body}")
    callback_response = http.request request
    $server.logger.info("Response from #{uri.to_s}: #{callback_response.inspect}")
  end

end

class DelayedResponse
  attr_accessor :request, :send_at, :status, :message, :url

  def parsed_body
    return nil if request.body.nil? || request.body == ""
    @parse_body ||= JSON.parse(request.body)
  end
end

class RunTask < WEBrick::HTTPServlet::AbstractServlet
  def do_POST(request, response)
    $server.logger.info("Received #{request.path}: #{request.body}")

    path_re = /\/(?'result'pass|fail|random)(?:$|-(?'delay'[\d]+))/
    route = nil
    uri_path = request.path.match(path_re)
    unless uri_path.nil?
      route = uri_path.named_captures['result']
      delay = uri_path.named_captures['delay'].to_i
      delay = rand(2...10) if delay.zero?
    end

    case route
    when 'random'
      if rand > 0.5
        send_pass(request, response, delay)
      else
        send_fail(request, response, delay)
      end
    when 'pass'
      send_pass(request, response, delay)
    when 'fail'
      send_fail(request, response, delay)
    else
      response.status = 404
    end
  end

  def send_fail(request, response, delay)
    $server.logger.info("Delaying Fail response by #{delay} seconds")

    delayed_response = DelayedResponse.new.tap do |dr|
      dr.request = request
      dr.send_at = Time::now + delay
      dr.status = 'failed'
      dr.message = 'Mock Always Fail'
    end

    $pending_jobs.push(delayed_response)
  end

  def send_pass(request, response, delay)
    $server.logger.info("Delaying Pass response by #{delay} seconds")

    delayed_response = DelayedResponse.new.tap do |dr|
      dr.request = request
      dr.send_at = Time::now + delay
      dr.status = 'passed'
      dr.message = 'Mock Always Passed'
    end
    $pending_jobs.push(delayed_response)
  end
end

$server = WEBrick::HTTPServer.new :Port => 8080, :Host => '0.0.0.0'
$server.mount '/', RunTask

Thread.new do
  while !$exit_now
    sleep 1

    idx = -1
    while !idx.nil?
      idx = $pending_jobs.find_index { |dr| Time::now > dr.send_at }
      if !idx.nil?
        respond_to($pending_jobs[idx])
        $pending_jobs.delete_at(idx)
      end
    end
  end
end

trap('INT') { # stop server with Ctrl-C
  $server.stop
  $exit_now = true
}
$server.start

#!/usr/bin/ruby

require 'json'

class RaftNode
  def initialize
    @node_id     = nil
    @node_ids    = nil
    @next_msg_id = 0
    @kv          = {}
  end

  # Generate a fresh message id
  def new_msg_id
    @next_msg_id += 1
  end

  # Send a body to the given node id
  def send!(dest, body)
    JSON.dump({dest: dest,
               src:  @node_id,
               body: body},
              STDOUT)
    STDOUT << "\n"
    STDOUT.flush
  end

  # Reply to a request with a response body
  def reply!(req, body)
    body[:in_reply_to] = req[:body][:msg_id]
    send! req[:src], body
  end

  def main
    STDERR.puts "Online"
    while true
      msg = JSON.parse(STDIN.gets, symbolize_names: true)
      STDERR.puts "Received #{msg.inspect}"
      body = msg[:body]

      case body[:type]
      when "raft_init"
        @node_id = body[:node_id]
        @node_ids = body[:node_ids]
        STDERR.puts "Raft init!"
        reply! msg, {type: "raft_init_ok"}

      when "write"
        @kv[body[:key]] = body[:value]
        reply! msg, {type: "write_ok"}

      when "read"
        reply! msg, {type: "read_ok", value: @kv[body[:key]]}

      when "cas"
        k = body[:key]
        if not (@kv.include? k)
          reply! msg, {type: "error",
                       code: 20,
                       text: "not found"}
        elsif @kv[k] != body[:from]
          reply! msg, {type: "error",
                       code: 22,
                       text: "expected #{body[:from]}, had #{@kv[k]}"}
        else
          @kv[k] = body[:to]
          reply! msg, {type: "cas_ok"}
        end
      end
    end
  end
end

RaftNode.new.main
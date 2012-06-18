#!/usr/bin/env ruby
# encoding: UTF-8

require "socket"
require "time"

class Client
  def initialize(host, port)
    # hostname (or ip adress) and port of the sip2-server
    @host, @port = host, port
  end

  def send_message(msg)
    connection do |socket|
      socket.puts(msg)
      result = socket.gets("\r") # read socket until carriage return
      return result
    end
  end

  def connection
    socket = Socket.new Socket::AF_INET, Socket::SOCK_STREAM, 0
    socket.connect Socket.pack_sockaddr_in @port, @host
    yield(socket)
  ensure
    socket.close
  end
end

def appendChecksum(msg)
  check = 0
  msg.each_char { |m| check += m.ord }
  check += "\0".ord
  check = (check ^ 0xFFFF) + 1

  checksum = "%4.4X" % check
  return msg + checksum
end

def formMessage(cardnr, pin)
  code = "63"
  language = "001"
  timestamp = Time.now.strftime("%Y%m%d    %H%M%S")
  summary = " " * 10
  msg = code + language + timestamp + summary + "AO|AA" + cardnr + "|AC|AD" + pin + "|AY1AZ"
  return msg
end

# -------------------------

if ARGV.length != 4
  puts "Usage: sip2auth.rb <HOST> <PORT> <CARD NUMBER> <CARD PIN>"
  exit
end

host, port, cardnr, pin = ARGV[0], ARGV[1], ARGV[2], ARGV[3]

msg = formMessage(cardnr, pin)
msg = appendChecksum(msg)
msg += "\r"

sip2client = Client.new(host, port)
result = sip2client.send_message msg
result.force_encoding("ISO-8859-1").encode("UTF-8")
#TODO check encoding, æøå => ?

cardnr = result.match /(?<=\|AA)(.*?)(?=\|)/
authorized = result.match /(?<=\|CQ)(.)(?=\|)/
bdate = result.match /(?<=\|PB)(.*?)(?=\|)/

puts "---------------------"
puts "Cardnr:    " + cardnr[0]
puts "Athorized: " + authorized[0]
puts "Age:       " + (Time.now.year - bdate[0][0,4].to_i).to_s

#TODO: test if cardnr nonexistant
# encoding: utf-8

# This class represents a message send by gdb
class Msg
  attr_accessor :msg_type # mi, record, async, stream,
  attr_reader :content_type # exec, status, notify, consol, log, target
  attr_accessor :token # numeric
  attr_accessor :value # value may be any json compilant structure such as hash/array fixnum etc. HOWEVER it may also be a ResultList due to stupid design decisions in gdb-mi 2

  def content_type=(ct)
    @content_type = case ct
                    when '*' then 'exec'
                    when '+' then 'status'
                    when '=' then 'notify'
                    when '~' then 'console'
                    when '@' then 'target'
                    when '&' then 'log'
                    else ct
                    end
  end

# constructor
# @param [String] msg_type the type of the message
# @param [String] content_type the type of the conntent of the message (such as
# "hallo" or "hook"). The content_type may be [*+=~@&] wich are mapped to exec,
# status, notify, console, target, log respectively.
# @param [Json] value the of content of the message, anything that can be
# serialized with json
# @param [Fixnum] token an id of the message (used to assign returns)
  def initialize(msg_type, content_type, value, token = nil)
    @msg_type, @value, @token = msg_type, value, token
    self.content_type=content_type
  end
end

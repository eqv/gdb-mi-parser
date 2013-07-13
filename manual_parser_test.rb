require_relative './manual_parser_optimized'
require 'wrong'
include Wrong

def test
  parser = ManualParser.new
  parser.verbose = true
  msg = parser.parse('&,"foo bar baz"')
  assert{ msg.msg_type == 'stream' }
  assert{ msg.content_type == 'log' }
  assert{ msg.value == 'foo bar baz' }
  puts "passed 1"

  msg = parser.parse('@"fnord bar \nbaz"')
  assert{ msg.msg_type == 'stream' }
  assert{ msg.content_type == 'target' }
  assert{ msg.value == 'fnord bar \nbaz' }
  puts "passed 2"

  res = parser.parse_tuple(parser.mk_state('{foo = "bar"}'))
  assert {res == {"foo" => "bar"} }
  puts "passed 3"

  res = parser.parse_result(parser.mk_state('goo={foo = "bar"}'))
  assert {res == {"goo" => {"foo" => "bar"} } }
  puts "passed 4"

  msg = parser.parse('123^foo,"this is a res"')
  assert{ msg.msg_type == 'record' }
  assert{ msg.content_type == 'foo' }
  assert{ msg.value == 'this is a res' }
  puts "passed 5"

  res = parser.parse_results(parser.mk_state('goo={foo = "bar"}, a="b"'))
  assert {res == {"goo" => {"foo" => "bar"}, "a" => "b" } }
  puts "passed 6"

  msg = parser.parse('123^foo,goo={foo="bar"}')
  assert{ msg.msg_type == 'record' }
  assert{ msg.content_type == 'foo' }
  assert{ msg.value == {"goo" => {"foo"=>"bar"} } }
  puts "passed 7"

  msg = parser.parse('123^foo,goo=["foo","bar","baz"]')
  assert{ msg.msg_type == 'record' }
  assert{ msg.content_type == 'foo' }
  assert{ msg.value == {"goo" => ["foo","bar","baz"] } }
  puts "passed 8"

  msg = parser.parse('123^foo,goo=[foo="bat",goo="bar",schnu="baz"]')
  assert{ msg.msg_type == 'record' }
  assert{ msg.content_type == 'foo' }
    is = msg.value["goo"].each_pair.to_a.sort_by{|x| x[0]}
    should = [["foo","bat"],["goo","bar"],["schnu","baz"]].sort_by{|x| x[0] }
  assert { is == should }
  puts "passed 9"

  msg = parser.parse('123^foo,goo=[foo="bat",foo="bar",foo="baz"]')
  assert{ msg.msg_type == 'record' }
  assert{ msg.content_type == 'foo' }
    is = msg.value["goo"].each_pair.to_a.sort_by{|x| x[1]}
    should = [["foo","bat"],["foo","bar"],["foo","baz"]].sort_by{|x| x[1] }
  assert { is == should }
  puts "passed 10"

  msg = parser.parse('123=foo,goo=[foo="bat"],foo="baz"')
  assert{ msg.msg_type == 'async' }
  assert{ msg.content_type == 'notify' }
  assert{ msg.value['event'] == 'foo' }
  assert { msg.value['info']['goo'].each_pair.to_a == [['foo','bat']] }
  assert { msg.value['info']['foo'] == 'baz' }
  puts "passed 11"

  msg = parser.parse('=foo')
  assert{ msg.msg_type == 'async' }
  assert{ msg.content_type == 'notify' }
  assert{ msg.value['event'] == 'foo' }
  assert { msg.value['info'] == nil }
  puts "passed 12"

  msg = parser.parse('1^connected')
  assert{ msg.msg_type == 'record' }
  assert{ msg.content_type == 'connected' }
  assert{ msg.value == nil }
  puts "passed 13"
end

test

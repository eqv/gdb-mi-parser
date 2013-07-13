require_relative './manual_parser_optimized.rb'
require 'benchmark'

line = '100^done,addr="0x000000000040059b",nr-bytes="1",total-bytes="1",next-row="0x000000000040059c",prev-row="0x000000000040059a",next-page="0x000000000040059c",prev-page="0x000000000040059a",memory=[{addr="0x000000000040059b",data=["0x05"]}]'

parser = ManualParser.new

res = Benchmark.measure do
  lastt = Time.now
  10000.times do |i|
    parser.parse line
    if i %100 == 0
      thist = Time.now
      puts "#{i} #{thist-lastt}"
      lastt = thist
    end
  end
end
puts res

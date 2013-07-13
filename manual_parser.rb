require_relative './msg.rb'
require_relative './result_list.rb'

class ParseState
  attr_accessor :msg, :tokens, :line, :index
  attr_accessor :verbose

  def tok
    @tokens[@index]
  end

  def lookahead(i)
    @tokens[@index+i]
  end

  def next
    @index+=1
    return self
  end

  def is_done?
    @index >= @tokens.length-1
  end

  def now(desc)
    puts "parsing #{desc} at #{@tokens[index..-1].join("")}" if @verbose
  end
end

class ManualParser

  attr_accessor :verbose
  def initialize(verbose = false)
    @verbose = verbose
  end

  def parse(line)
    line = line.strip.chomp('\n') 
    #THIS chomp('\n') is not a bug, gdb sometimes appends a literal '\n' this is a confirmed
    #gdb bug. This workaround should become obsolete sometime in the future
    return Schem::Msg.new(nil, 'gdb', 'done') if line == "(gdb)"
    state = mk_state(line)
    parse_msg(state)
    return state.msg
  end

  def mk_state(line)
    line = line.strip.chomp('\n')
    tokenized=line.scan(/[,=*+~@&{}^\[\]]|"(?:[^"\\]|\\.)*"|[\w\-]+/)
    state = ParseState.new
    state.msg = Schem::Msg.new(nil,nil,nil,nil)
    state.index = 0
    state.tokens = tokenized
    state.verbose = @verbose
    state.line = line
    state
  end

# private TODO comment in

    def is_token?(state)
      return state.tokens[state.index] =~ /\A[0-9]+\Z/
    end

    def is_string?(state)
      return state.tokens[state.index] =~ /\A"(?:[^"\\]|\\.)*"\Z/
    end

    def is_word?(state)
      return state.tokens[state.index] =~ /\A[\w\-]+\Z/
    end

    def is_stream_start?(state)
      return state.tok =~ /\A[~&@]\Z/
    end

    def is_async_start?(state)
      return state.tok =~ /\A[=*+]\Z/
    end

    def is_record_start?(state)
      return state.tok == '^'
    end

    def parse_string(state)
      state.now("string")
      if is_string?(state)
        res = state.tok[1..-2]
        state.next
        return res
      else
        failure(state,"expected a string")
      end
    end

    def parse_word(state)
      state.now("word")
      if is_word?(state)
        res = state.tok
        state.next
        return res
      else
        failure(state,"expected a word")
      end
    end

    def parse_msg(state)
      state.now("msg")
      if is_token?(state)
        state.msg.token = state.tok.to_i
        state.next
      end
      if is_stream_start?(state)
          state.msg.msg_type = 'stream'
          state.msg.content_type = state.tok
          parse_stream(state.next)
      elsif is_record_start?(state)
          state.msg.msg_type = 'record'
          parse_record(state.next)
      elsif is_async_start?(state)
          state.msg.msg_type = 'async'
          state.msg.content_type = state.tok
          parse_async(state.next)
      else
          failure(state, "expected a async_start or record_start")
      end
    end

    def parse_stream(state)
      state.now("stream")
      state.next if state.tok == ","
      state.msg.value = parse_string(state)
      done(state)
    end

    def parse_record(state)
      state.now("record")
      type = parse_word(state)
      state.msg.content_type = type
      return if state.is_done?
      failure(state,"expected ','") unless state.tok == ","
      state.next
      if is_word?(state)
        if state.lookahead(1) == '='
          state.msg.value = parse_results(state)
          done(state)
        else
          failure(state, "expected result")
        end
      else
        state.msg.value = parse_string(state)
        done(state)
      end
    end

    def parse_async(state)
      state.now("async")
      event = parse_word(state)
      state.msg.value = {"event"=>event}
      if state.tok == ","
        state.msg.value["info"] = parse_results(state.next)
      end
      done(state)
    end

    def parse_result(state)
      state.now("result")
      name = parse_word(state)
      failure("expected '='") unless state.tok == '='
      val = parse_value(state.next)
      state.now("result done")
      return {name => val}
    end

    def parse_value(state)
      state.now("value")
      if is_string?(state)
        return parse_string(state)
      elsif state.tok == '{'
        return parse_tuple(state)
      elsif state.tok == '['
        return parse_list(state)
      else
        failure("expected array, tuple or string",state)
      end
    end

    def parse_list(state)
      state.now("tuple")
      failure "expected list ('[')", state unless state.tok == '['
      state.next
      if state.tok == ']'
        state.next
        return []
      end
      if state.lookahead(1) == '='
        res = parse_list_results(state)
      else
        res = parse_values(state)
      end
      failure(state,"expected ']'") unless state.tok == ']'
      state.next
      return res
    end

    def parse_tuple(state)
      state.now("tuple")
      failure "expected tuple ('{')", state unless state.tok == '{'
      state.next
      if state.tok == '}'
        state.next
        return {}
      end
      res = parse_results(state)
      failure(state,"expected '}'") unless state.tok == '}'
      state.next
      return res
    end

    def parse_values(state)
      state.now("values")
      values = [parse_value(state)]
      state.now("more values")
      loop do
        break if state.tok != ","
        values << parse_value(state.next)
      end
      state.now("no more values")
      return values
    end

    def parse_results(state)
      state.now("results")
      merged = parse_result(state)
      state.now("more results")
      loop do
        break if state.tok != ","
        merged = parse_result(state.next).merge(merged)
      end
      state.now("no more results")
      return merged
    end

    def parse_list_results(state)
      state.now("list results")
      merged = ResultList.new(parse_result(state))
      state.now("more list results")
      loop do
        break if state.tok != ","
        merged.merge!(parse_result(state.next))
      end
      state.now("no more list results")
      return merged
    end

    def done(state)
      failure(state, "expected end of string") if state.index < state.tokens.length-1
    end

    def failure(state,desc)
      raise desc+" at: #{state.tokens[state.index..-1].join("").inspect}\n in: #{state.line.inspect}"
    end

end

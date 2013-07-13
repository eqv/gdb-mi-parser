require_relative './msg.rb'
require_relative './result_list.rb'

class ParseState
  attr_accessor :msg, :tokens, :line, :index
  attr_accessor :verbose

  def lookahead(i)
    @tokens[@index+i]
  end

  def is_done?
    @index >= @tokens.length-1
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
    return Msg.new(nil, 'gdb', 'done') if line == "(gdb)"
    state = mk_state(line)
    parse_msg(state)
    return state.msg
  end

  def mk_state(line)
    tokenized=line.scan(/[,=*+~@&{}^\[\]]|"(?:[^"\\]|\\.)*"|[\w\-]+/)
    state = ParseState.new
    state.msg = Msg.new(nil,nil,nil,nil)
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
      return state.tokens[state.index]  =~ /\A[~&@]\Z/
    end

    def is_async_start?(state)
      return state.tokens[state.index] =~ /\A[=*+]\Z/
    end

    def is_record_start?(state)
      return state.tokens[state.index] == '^'
    end

    def parse_string(state)
      if state.tokens[state.index] =~ /\A"(?:[^"\\]|\\.)*"\Z/
        res = state.tokens[state.index][1..-2]
        state.index+=1
        return res
      else
        failure(state,"expected a string")
      end
    end

    def parse_word(state)
      if is_word?(state)
        res = state.tokens[state.index]
        state.index+=1
        return res
      else
        failure(state,"expected a word")
      end
    end

    def parse_msg(state)
      if is_token?(state)
        state.msg.token = state.tokens[state.index].to_i
        state.index+=1
      end
      if is_stream_start?(state)
          state.msg.msg_type = 'stream'
          state.msg.content_type = state.tokens[state.index]
          state.index+=1
          parse_stream(state)
      elsif is_record_start?(state)
          state.msg.msg_type = 'record'
          state.index+=1
          parse_record(state)
      elsif is_async_start?(state)
          state.msg.msg_type = 'async'
          state.msg.content_type = state.tokens[state.index]
          state.index+=1
          parse_async(state)
      else
          failure(state, "expected a async_start or record_start")
      end
    end

    def parse_stream(state)
      state.index+=1 if state.tokens[state.index] == ","
      state.msg.value = parse_string(state)
      done(state)
    end

    def parse_record(state)
      type = parse_word(state)
      state.msg.content_type = type
      return if state.is_done?
      failure(state,"expected ','") unless state.tokens[state.index] == ","
      state.index+=1
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
      event = parse_word(state)
      state.msg.value = {"event"=>event}
      if state.tokens[state.index] == ","
        state.index+=1
        state.msg.value["info"] = parse_results(state)
      end
      done(state)
    end

    def parse_result(state)
      name = parse_word(state)
      failure("expected '='") unless state.tokens[state.index] == '='
      state.index+=1
      val = parse_value(state)
      return {name => val}
    end

    def parse_value(state)
      tok = state.tokens[state.index]
      if tok =~ /\A"(?:[^"\\]|\\.)*"\Z/
        return parse_string(state)
      elsif tok == '{'
        return parse_tuple(state)
      elsif tok == '['
        return parse_list(state)
      else
        failure("expected array, tuple or string",state)
      end
    end

    def parse_list(state)
      failure "expected list ('[')", state unless state.tokens[state.index] == '['
      state.index+=1
      if state.tokens[state.index] == ']'
        state.index+=1
        return []
      end
      if state.lookahead(1) == '='
        res = parse_list_results(state)
      else
        res = parse_values(state)
      end
      failure(state,"expected ']'") unless state.tokens[state.index] == ']'
      state.index+=1
      return res
    end

    def parse_tuple(state)
      failure "expected tuple ('{')", state unless state.tokens[state.index] == '{'
      state.index+=1
      if state.tokens[state.index] == '}'
        state.index+=1
        return {}
      end
      res = parse_results(state)
      failure(state,"expected '}'") unless state.tokens[state.index] == '}'
      state.index+=1
      return res
    end

    def parse_values(state)
      values = [parse_value(state)]
      loop do
        break if state.tokens[state.index] != ","
        state.index+=1
        values << parse_value(state)
      end
      return values
    end

    def parse_results(state)
      merged = parse_result(state)
      loop do
        break if state.tokens[state.index] != ","
        state.index+=1
        merged = parse_result(state).merge(merged)
      end
      return merged
    end

    def parse_list_results(state)
      merged = ResultList.new(parse_result(state))
      loop do
        break if state.tokens[state.index] != ","
        state.index+=1
        merged.merge!(parse_result(state))
      end
      return merged
    end

    def done(state)
      failure(state, "expected end of string") if state.index < state.tokens.length-1
    end

    def failure(state,desc)
      raise desc+" at: #{state.tokens[state.index..-1].join("").inspect}\n in: #{state.line.inspect}"
    end

end

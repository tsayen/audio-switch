require 'pty'

module AudioSwitch
  class Pactl
    def move_input(input_id, sink_id)
      `pactl move-sink-input #{input_id} #{sink_id}`
    end

    def default_sink=(sink_id)
      # pactl doesn't have this command
      `pacmd set-default-sink #{sink_id}`
    end

    def sinks
      default_sink_name = self.class.parse_default_sink(`pactl stat`)
      self.class.parse_sinks(`pactl list sinks`, default_sink_name)
    end

    def inputs
      self.class.parse_inputs(`pactl list sink-inputs`)
    end

    def modules
      self.class.parse_modules(`pactl list modules`)
    end

    def load_module(mod, options = {})
      `pactl load-module #{mod} #{self.class.format_module_opts(options)}`
    end

    def unload_module(mod)
      `pactl unload-module #{mod}`
    end

    def subscribe(command = 'pactl subscribe')
      Thread.start do
        @pactl_sub = PTY.spawn(command)[0]
        begin
          @pactl_sub.each do |line|
            yield(self.class.parse_event(line))
          end
        rescue Errno::EIO, IOError
          return
        end
      end
    end

    def dispose
      @pactl_sub.close
    end

    def self.format_module_opts(opts, quote = '')
      result = ''
      opts.each_pair do |key, value|
        result += ' ' unless result.empty?
        result += if value.is_a? Hash
                    "#{key}=\\\"#{format_module_opts(value, '\\\'')}\\\""
                  else
                    "#{key}=#{quote}#{value}#{quote}"
                  end
      end
      result
    end

    def self.parse_sinks(out, default_sink_name)
      sinks = []
      sink = nil
      out.each_line do |line|
        case line
        when /Sink #/
          sink = { id: read_id(line) }
        when /Name:/
          sink[:name] = read_name(line)
          sink[:default] = true if sink[:name] == default_sink_name
        when /Description:/
          sink[:description] = read_property(line, 'Description:')
          sinks << sink
          sink = nil
        end
      end
      sinks
    end

    def self.parse_inputs(out)
      out.split("\n")
         .select { |line| line =~ /^Sink Input #/ }
         .map { |line| { id: read_id(line) } }
    end

    def self.parse_event(out_line)
      parts = out_line.split(' ')
      {
        type: parts[1].delete('\'').to_sym,
        object: parts[3].to_sym,
        id: parts[4].sub('#', '')
      }
    end

    def self.parse_default_sink(out)
      out.match(/^Default Sink: (.*?)\n/)[1]
    end

    def self.parse_modules(out)
      modules = []
      mod = nil
      out.each_line do |line|
        case line
        when /Module #/
          mod = {}
        when /Name:/
          mod[:name] = read_name(line)
          modules << mod
          mod = nil
        end
      end
      modules
    end

    def self.parse_sources(out)
      sources = []
      source = nil
      out.each_line do |line|
        case line
        when /Source #/
          source = { id: read_id(line) }
        when /Mute:/
          source[:mute] = (read_property(line, 'Mute:') == 'yes')
          sources << source
          source = nil
        end
      end
      sources
    end

    def self.read_id(line)
      read_property(line, '#')
    end

    def self.read_name(line)
      read_property(line, 'Name:')
    end

    def self.read_property(line, label)
      line.match(Regexp.new("#{label}\\s*(.*?)\\s*$"))[1]
    end
  end
end

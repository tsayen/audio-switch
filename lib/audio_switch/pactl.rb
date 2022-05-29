require 'pty'

module AudioSwitch
  class Pactl
    def move_input(input_id, sink_id)
      AudioSwitch::LOG.info "moving sink input '#{input_id}' to sink '#{sink_id}'"
      `pactl move-sink-input #{input_id} #{sink_id}`
    end

    def default_sink=(sink_id)
      AudioSwitch::LOG.info "setting default sink to '#{sink_id}'"
      # pactl doesn't have this command
      `pactl set-default-sink #{sink_id}`
    end

    def sinks
      default_sink_name = `pactl get-default-sink`.strip
      self.class.parse_sinks(`pactl list sinks`, default_sink_name)
    end

    def inputs
      self.class.parse_inputs(`pactl list sink-inputs`)
    end

    def modules
      self.class.parse_modules(`pactl list modules`)
    end

    def sources
      self.class.parse_sources(`pactl list sources`)
    end

    def load_module(mod, options = {})
      AudioSwitch::LOG.info "loading module '#{mod}' with options '#{options}'"
      `pactl load-module #{mod} #{ModuleOptions.new(options)}`
    end

    def unload_module(mod)
      AudioSwitch::LOG.info "unloading module '#{mod}'"
      `pactl unload-module #{mod}`
    end

    def subscribe(command = 'pactl subscribe')
      Thread.start do
        AudioSwitch::LOG.info "starting '#{command}'"
        @pactl_sub = PTY.spawn(command)[0]
        begin
          @pactl_sub.each do |line|
            yield(Out.new(line).parse_event)
          end
        rescue Errno::EIO, IOError => e
          AudioSwitch::LOG.error("reading '#{command}' output") { e }
        end
      end
    end

    def mute_source(source_id)
      AudioSwitch::LOG.info "muting source '#{source_id}'"
      `pactl set-source-mute #{source_id} true`
    end

    def unmute_source(source_id)
      AudioSwitch::LOG.info "unmuting source '#{source_id}'"
      `pactl set-source-mute #{source_id} false`
    end

    def dispose
      @pactl_sub.close
    end

    def self.parse_sinks(out, default_sink_name)
      Out.new(out).parse_objects(
        [
          { marker: 'Sink #', property: :id },
          { marker: 'Name:', property: :name },
          { marker: 'Description:', property: :description }
        ]
      ).each { |sink| sink[:default] = true if sink[:name] == default_sink_name }
    end

    def self.parse_inputs(out)
      Out.new(out).parse_objects(
        [
          { marker: 'Sink Input #', property: :id }
        ]
      )
    end

    def self.parse_modules(out)
      Out.new(out).parse_objects(
        [
          { marker: 'Module #' },
          { marker: 'Name:', property: :name }
        ]
      )
    end

    def self.parse_sources(out)
      Out.new(out).parse_objects(
        [
          { marker: 'Source #', property: :id },
          { marker: 'Name:', property: :name },
          { marker: 'Mute:', property: :mute }
        ]
      ).each { |source| source[:mute] = source[:mute] == 'yes' }
    end

    class Out
      def initialize(string)
        @string = string
      end

      def parse_objects(fields)
        objects = []
        field_id = 0
        object = nil

        @string.each_line do |line|
          field = fields[field_id]
          next unless line =~ Regexp.new(field[:marker])

          object = {} if field_id.zero?
          update(object, line, field)

          field_id += 1
          next unless field_id == fields.size

          objects << object
          object = nil
          field_id = 0
        end

        objects
      end

      def parse_event
        parts = @string.split(' ')
        {
          type: parts[1].delete('\'').to_sym,
          object: parts[3].to_sym,
          id: parts[4].sub('#', '')
        }
      end

      def parse_property(marker)
        read_property(@string, marker)
      end

      private

      def update(object, line, field)
        property = field[:property]
        object[property] = read_property(line, field[:marker]) if field[:property]
      end

      def read_property(line, marker)
        line.match(Regexp.new("#{marker}\\s*(.*?)\\s*$"))[1]
      end
    end

    class ModuleOptions
      def initialize(options)
        @options = options
      end

      def to_s
        format(@options)
      end

      def format(opts, quote = '')
        result = ''
        opts.each_pair do |key, value|
          result += ' ' unless result.empty?
          result += if value.is_a? Hash
                      "#{key}=\\\"#{format(value, '\\\'')}\\\""
                    else
                      "#{key}=#{quote}#{value}#{quote}"
                    end
        end
        result
      end
    end
  end
end

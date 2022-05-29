require 'logger'
require_relative 'app_logger'
require_relative 'audio_switch/pactl'
require_relative 'audio_switch/model'
require_relative 'audio_switch/ui'
require_relative 'audio_switch/version'

module AudioSwitch
  LOG = configure_logger

  module App
    def self.start
      AudioSwitch::LOG.info("starting audio_switch #{AudioSwitch::VERSION} on ruby #{RUBY_VERSION}")
      pactl = AudioSwitch::Pactl.new
      model = AudioSwitch::Model.new(pactl)
      ui = AudioSwitch::UI.new(model)
      ui.start
    end

    def self.quit
      AudioSwitch::LOG.info('quitting audio_switch')
      exit
    end
  end
end

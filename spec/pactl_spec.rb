require_relative 'test_logger'
require 'audio_switch/pactl'
require 'rspec/wait'

Pactl = AudioSwitch::Pactl
describe Pactl do
  it 'should parse pactl sinks output' do
    sinks = Pactl.parse_sinks(File.read('spec/resources/pactl_list_sinks'),
                              'alsa_output.pci-0000_00_1b.0.analog-stereo')

    expect(sinks).to \
      eql([{
            id: '0',
            name: 'alsa_output.pci-0000_00_1b.0.analog-stereo',
            description: 'Built-in Audio Analog Stereo',
            default: true
          }, {
            id: '1',
            name: 'rtp',
            description: 'RTP Multicast'
          }])
  end

  it 'should parse pactl inputs output' do
    inputs = Pactl.parse_inputs(File.read('spec/resources/pactl_list_inputs'))

    expect(inputs).to eql([{ id: '100' }, { id: '104' }])
  end

  it 'should parse pactl modules' do
    modules = Pactl.parse_modules(File.read('spec/resources/pactl_list_modules'))

    expect(modules).to include(name: 'module-rtp-send')
  end

  it 'should parse pactl sources' do
    sources = Pactl.parse_sources(File.read('spec/resources/pactl_list_sources'))

    expect(sources).to eql(
      [
        { id: '1', mute: true, name: 'alsa_input.pci-0000_00_1b.0.analog-stereo' },
        { id: '110', mute: false, name: 'alsa_output.pci-0000_00_1b.0.analog-stereo.monitor' }
      ]
    )
  end

  it 'should notify of events' do
    command =
      "while : ; do
    #{
      [
        "Event 'new' on sink-input '#72'",
        "Event 'change' on sink '#0'",
        "Event 'remove' on sink-input '#60'"
      ]
              .map { |line| "echo #{line}" }
              .join('; ')
    };
    done"

    pactl = Pactl.new
    events = []

    pactl.subscribe(command) do |event|
      events.push(event)
      pactl.dispose if events.size == 3
    end

    wait_for(events).to \
      eql([{
            type: :new,
            object: :'sink-input',
            id: '72'
          }, {
            type: :change,
            object: :sink,
            id: '0'
          }, {
            type: :remove,
            object: :'sink-input',
            id: '60'
          }])
  end

  it 'should format module options' do
    options1 = { 'name' => 'rtp', 'channels' => '2' }
    options2 = { 'name' => 'rtp', 'options' => { 'description' => 'RTP' } }

    expect(Pactl::ModuleOptions.new(options1).to_s).to eql('name=rtp channels=2')
    expect(Pactl::ModuleOptions.new(options2).to_s).to eql("name=rtp options=\\\"description=\\\'RTP\\\'\\\"")
  end
end

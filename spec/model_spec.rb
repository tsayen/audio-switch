require 'model.rb'

RSpec.describe PulseAudioSwitch::Model do
  it 'should get sinks from pulseaudio' do
    # given
    sinks = [{ id: 'sink0', title: 'Sink 0', active: false },
             { id: 'sink1', title: 'Sink 1', active: true }]
    pulseaudio = instance_double('PulseAudioSwitch::PulseAudio',
                                 sinks: sinks)
    model = PulseAudioSwitch::Model.new(pulseaudio)
    expect(pulseaudio).to receive(:sinks).once
    # then
    expect(model.sinks).to equal(sinks)
  end
end

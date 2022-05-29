# Audio switch applet for Ubuntu

Provides an indicator that lets one switch between pulseaudio sinks, toggle RTP sink and inputs. Applet is tested on
Ubuntu 22.04. It uses `pactl` to control sound settings.

## Installation

Applet can be downloaded as a Ruby gem `audio_switch`. It depends on `libappindicator-dev` and `libcanberra-gtk-module`.

```bash
apt-get install libappindicator-dev libcanberra-gtk-module
gem install audio_switch
```  

## Running

```bash
audio_switch
```

![screenshot](img/screenshot.png)

## Author

Anatolii Saienko

## License  

MIT

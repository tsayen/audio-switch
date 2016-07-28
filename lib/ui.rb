require 'gtk2'
require 'ruby-libappindicator'

module AudioSwitch
  class UI
    def initialize(model)
      @model = model
      @menu = Gtk::Menu.new
      @items = []
      add_to_tray
      subscribe
    end

    private

    def add_to_tray
      indicator = AppIndicator::AppIndicator.new(
        self.class.name,
        'multimedia-volume-control',
        AppIndicator::Category::HARDWARE
      )
      indicator.set_menu(@menu)
      indicator.set_status(AppIndicator::Status::ACTIVE)
    end

    def subscribe
      @model.watch { draw(@model.sinks) }
    end

    def draw(sinks)
      clear
      sinks.each { |sink| add new_item(sink) }
    end

    def add(item)
      @menu.append item
      @items.push item
      item.show
    end

    def new_item(sink)
      item = Gtk::RadioMenuItem.new(@items, sink[:description])
      item.signal_connect('toggled') do
        @model.select_sink(sink[:id]) if item.active?
      end
      item.set_active(sink[:default])
      item
    end

    def clear
      @menu.remove(@items.pop) until @items.empty?
    end
  end
end

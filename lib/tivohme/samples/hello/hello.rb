require 'tivohme'

TITLE = "Hello World"

class Hello < ::TivoHME::Application
  def startup
    ::TivoHME::Font.new(self, size: 36, style: FONT_BOLD)
    root.set_text('Hello, world!')
  end
end

module TivoHME

  # Text resource (with chosen Color and Font)
  # If either the color or font is unspecified, the last ones set in
  # the app are used. The color can be specified by number (using
  # colornum=), or as an object of the Color class (color=). The
  # font can only be specified as an object of the Font class.
  class Text < Resource

    def initialize (app, text, font: nil, color: nil, colornum: nil)
      super(app)

      if color.nil?
        if ! colornum.nil?
          color = Color.new(app, colornum)
        else
          color = app.last_color
          if color.nil?
            color = Color.new(app)
          end
        end
      end
      if font.nil?
        font = app.last_font
        if font.nil?
          font = Font.new(app)
        end
      end
      put(CMD_RSRC_ADD_TEXT, 'iis', font.id, color.id, text)
    end

    # TODO: need finalizer for ruby
    # ObjectSpace.define_finalizer(self, self.class.method(:finalize).to_proc)
    # def self.finalize(id)
    #   Resource.remove(self)
    # end

  end

end

module TivoHME

  # Font resource (with chosen point size and style)
  # ttf specifies an object of the TTF class, and defaults to the
  # ID_DEFAULT_TTF object. style can be FONT_ITALIC, FONT_BOLD, or
  # FONT_BOLDITALIC, and defaults to FONT_PLAIN. Font objects are
  # cached in the app.fonts dict, and the last Font set is stored in
  # app.last_font.
  class Font < Resource
    attr_accessor :ascent, :descent, :height, :line_gap, :glyphs

    def initialize (app, ttf: nil, style: FONT_PLAIN, size: 24, flags: 0)
      if ttf.nil?
        ttf = app.last_ttf
        if ttf.nil?
          ttf = app.default_ttf
        end
      end
      @key = [ttf, style, size, flags]

      if app.fonts.include?(@key)
        super(app, app.fonts[@key].id)
      else
        super(app)
        put(CMD_RSRC_ADD_FONT, 'iifi', ttf.id, style, size, flags)
        app.fonts[@key] = self
      end
      app.last_font = self
    end

    def remove
      super
      @app.fonts.delete(@key)
      if @app.last_font == self
        @app.last_font = nil
      end
    end

  end

end

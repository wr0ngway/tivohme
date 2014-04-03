module TivoHME

  # Color resource
  # The colornum is specified as an integer in standard web R/G/B
  # format (most convenient as hex). If none is given, white (the
  # typical font color for the TiVo interface) is used. Color
  # objects are cached in the app.colors dict, and the last one set
  # is also stored in app.last_color.
  #
  # You can include an alpha value as the MSB. Zero is treated as
  # 0xff (fully opacity) by this library; otherwise, lower numbers
  # mean greater transparency.
  class Color < Resource

    def initialize(app, colornum=nil)
      if colornum.nil?
        colornum = 0xffffffff
      end

      if (colornum & 0xff000000) == 0
        colornum |= 0xff000000
      end

      @colornum = colornum
      if app.colors.include?(colornum)
        super(app, app.colors[colornum].id)
      else
        super(app)
        put(CMD_RSRC_ADD_COLOR, 'r', [colornum].pack('N'))
        app.colors[colornum] = self
      end

      app.last_color = self
    end

    def remove
      super
      @app.colors.delete(@colornum)
      if @app.last_color == self
        @app.last_color = nil
      end
    end

  end

end

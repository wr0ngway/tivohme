module TivoHME

  # Base class for Resources
  # Note that in this implementation, resources are never removed
  # automatically; you have to call the remove() method.
  class Resource < TivoHME::Object

    def initialize(app, id=nil)
      super(app, id)
      @speed = 0
    end

    def set_active(make_active=true)
      put(CMD_RSRC_SET_ACTIVE, 'b', make_active)
    end

    def set_position(position)
      put(CMD_RSRC_SET_POSITION, 'i', position)
    end

    def set_speed(speed)
      put(CMD_RSRC_SET_SPEED, 'f', speed)
      @speed = speed
      @app.wfile.flush() rescue nil
    end

    def close
      put(CMD_RSRC_CLOSE)
    end

    def remove
      if @id >= ID_CLIENT
        put(CMD_RSRC_REMOVE)
        @id = -1
      end
    end

    def play
      set_speed(1)
    end

    def pause
      set_speed(0)
    end

  end

end

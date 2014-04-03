module TivoHME

  # Animation resource
  # Specified by duration in seconds, with optional ease and id.
  # (The id is used to initalize a zero-duration object for
  # ID_NULL.) Animation objects are cached in the app.anims dict.
  class Animation < Resource

    def initialize (app, duration, ease: 0, id: nil)
      @key = [duration, ease]
      if id.nil?
        if app.anims.include?(@key)
          super(app, app.anims[@key].id)
        else
          super(app)
          put(CMD_RSRC_ADD_ANIM, 'if', duration * 1000, ease)
          app.anims[@key] = self
        end
      else
        super(app, id)
      end
    end

    def remove
      super
      @app.anims.delete(@key)
    end

  end

end

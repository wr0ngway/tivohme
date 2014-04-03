module TivoHME

  # Sound resource
  # Specified by data, file object, file name or id. If none is
  # given, ID_UPDOWN_SOUND is used.
  #
  # Note that, on a real TiVo, only the predefined sounds seem to
  # work. Use a Stream to play your own sounds.
  class Sound < Resource

    def initialize (app, name: nil, f: nil, data: nil, id: nil)
      if data.nil? and f.nil? and name.nil? and id.nil?
        id = ID_UPDOWN_SOUND
      end

      super(app, id)

      if id.nil?
        if data.nil?
          if f.nil?
            f = File.open(name, 'rb')
          end
          data = f.read()
        end
        put(CMD_RSRC_ADD_SOUND, 'r', data)
      end
    end

  end

end
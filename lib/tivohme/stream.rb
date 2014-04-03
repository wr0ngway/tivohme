module TivoHME

  # Stream resource
  # Specified by url. You can also provide the MIME type here, but
  # it doesn't seem to be used. The default is to play the stream
  # automatically when the event is sent; you can change this by
  # specifying "play=False". However, streams seem to be playable
  # only once.
  class Stream < Resource

    def initialize (app, url, mime: '', play: true, params: {})
      super(app)
      put(CMD_RSRC_ADD_STREAM, 'ssbd', url, mime, play, params)
      @speed = play.to_i
    end

    # TODO: need finalizer for ruby
    # ObjectSpace.define_finalizer(self, self.class.method(:finalize).to_proc)
    # def self.finalize(id)
    #   Resource.remove(self)
    # end

  end

end

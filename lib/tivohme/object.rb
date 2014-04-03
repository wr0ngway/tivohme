module TivoHME

  # Base class for Resources and Views
  # If the id is specified, it's used; otherwise the next available
  # id is fetched from the app.
  #
  # The need to specify the app here results in a slew of "self"
  # parameters when _HMEObjects are being constructed -- probably
  # the ugliest aspect of this module.
  class Object
    # Commands

    include GemLogger::LoggerSupport
    include TivoHME::Constants

    attr_reader :id, :app

    def initialize(app, id=nil)
      if id.nil?
        @id = app.next_resnum()
      else
        @id = id
      end
      @app = app
    end

    # Send a command (cmd) with the current resource id and
    # specified parameters, if any. The parameters are packed
    # according to the format string.
    def put (cmd, format='', *params)
      data = EventData.pack('ii' + format, cmd, @id, *params)
      EventData.put_chunked(@app.wfile, data)
    end

  end

end

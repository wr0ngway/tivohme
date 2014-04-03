module TivoHME

  # The Application class
  # Your apps should subclass this. It takes over just after the
  # HTTP connection is established, does the HME handshake, sets up
  # some default resources and caches for new ones, and handles the
  # startup events.
  #
  # When started from start.py, the server's handler is passed as
  # context; alternatively, you can pass infile and outfile, and
  # (potentially) start the app from the command line.
  class Application < Resource

    attr_accessor :colors, :ttfs, :fonts, :images, :anims,
                  :default_ttf, :system_ttf, :immediate,
                  :last_color, :last_ttf, :last_font,
                  :focus, :current_resolution, :resolutions,
                  :active, :answer, :rfile, :wfile, :root,
                  :context

    :last_ttf

    def initialize(infile: nil, outfile: nil, context: nil)
      super(self, ID_ROOT_STREAM)

      @resnum = ID_CLIENT

      @context = context
      if ! context.nil?
        @rfile = context.rfile
        @wfile = context.wfile
      else
        @rfile = infile
        @wfile = outfile
      end

      # Resource caches
      @colors = {}
      @ttfs = {}
      @fonts = {}
      @images = {}
      @anims = {}

      # Default resources
      @default_ttf = TTF.new(self)
      @system_ttf = TTF.new(self, id: ID_SYSTEM_TTF)
      @immediate = Animation.new(self, 0, id: ID_NULL)

      @last_color = nil
      @last_ttf = nil
      @last_font = nil
      @focus = nil

      @current_resolution = [640, 480, 1, 1]
      @resolutions = [@current_resolution]
      @active = false

      # The HME handshake
      hs = "SBTV\0\0%c%c" % [HME_MAJOR_VERSION.chr, HME_MINOR_VERSION.chr]
      @wfile.write(hs.encode('US-ASCII'))
      @wfile.flush()
      @answer = @rfile.read(8)
      # @answer[-2:] contains the reciever's supported HME
      # version, if you care. (I get 0.45 with TiVo 9.2.)

      # The root view object
      @root = View.new(self, id: ID_ROOT_VIEW)
    end

    # The main loop -- startup, handle events, cleanup, exit.
    # Call this after initializing the app object.
    def mainloop
      if not @answer.start_with?('SBTV')
        return
      end

      @active = true
      startup()
      @root.set_visible()

      # Run events until there are no more, or until @active.equal?
      # set to false.
      while @active and get_event()
      end

      @active = false
      cleanup()
      set_active(false)

      # Discard any pending events
      while get_event()
      end
    end

    # Return the next available resource ID number, starting from
    # ID_CLIENT.
    def next_resnum
      x = @resnum
      @resnum += 1
      return x
    end

    # The main event handler/dispatcher. Attempts to get one
    # event; returns False if it can't. Otherwise, unpacks the
    # event data, calls the handler function (see below),
    # processes the return value (in the case of EVT_IDLE or
    # EVT_RESOLUTION_INFO), and returns True.
    def get_event
      begin
        @wfile.flush()
      rescue
        return false
      end

      data = EventData.get_chunked(@rfile)
      if not data
        return false
      end

      ev = EventData.new(data)

      evnum, resource = ev.unpack('ii')

      if evnum == EVT_KEY

        action, keynum, rawcode = ev.unpack('iii')

        if action == KEY_PRESS
          handle = get_method_handle(@focus, :handle_key_press)
        elsif action == KEY_REPEAT
          handle = get_method_handle(@focus, :handle_key_repeat)
        elsif action == KEY_RELEASE
          handle = get_method_handle(@focus, :handle_key_release)
        end

        handle.call(keynum, rawcode)

      elsif evnum == EVT_DEVICE_INFO

        info = {}
        count = ev.unpack('i')[0]
        count.times do |i|
          key, value = ev.unpack('ss')
          info[key] = value
        end
        handle = get_method_handle(@focus, :handle_device_info)
        handle.call(info)

      elsif evnum == EVT_APP_INFO

        info = {}
        count = ev.unpack('i')[0]
        count.times do |i|
          key, value = ev.unpack('ss')
          info[key] = value
        end

        if info.has_key? 'error.code'
          code = info['error.code']
          text = info.get('error.text', '')
          handle = get_method_handle(@focus, :handle_error)
          handle.call(code, text)
        elsif info.has_key? 'active'
          if info['active'] == 'true'
            handle = get_method_handle(@focus, :handle_active)
            handle.call()
          else
            return false
          end
        else
          handle = get_method_handle(@focus, :handle_app_info)
          handle.call(info)
        end

      elsif evnum == EVT_RSRC_INFO

        info = {}
        status, count = ev.unpack('ii')
        count.times do |i|
          key, value = ev.unpack('ss')
          info[key] = value
        end

        handle = get_method_handle(@focus, :handle_resource_info)
        handle.call(resource, status, info)

      elsif evnum == EVT_IDLE

        idle = ev.unpack('b')[0]
        handle = get_method_handle(@focus, :handle_idle)
        handled = handle.call(idle)
        put(CMD_RECEIVER_ACKNOWLEDGE_IDLE, 'b', handled)

      elsif evnum == EVT_FONT_INFO

        for font in @fonts.values()
          if font.id == resource
            break
          end
        end

        font.ascent, font.descent, font.height, font.line_gap,
            extras, count = ev.unpack('ffffii')
        extras -= 3
        font.glyphs = {}

        count.times do |i|
          id, advance, bounding = ev.unpack('iff')
          ev.index += 4 * extras
          font.glyphs[id.chr(Encoding::UTF_8)] = [advance, bounding]
        end
        handle = get_method_handle(@focus, :handle_font_info)
        handle.call(font)

      elsif evnum == EVT_INIT_INFO
        params, memento = ev.unpack('dv')
        handle = get_method_handle(@focus, :handle_init_info)
        handle.call(params, memento)

      elsif evnum == EVT_RESOLUTION_INFO

        field_count = ev.unpack('i')[0]
        @current_resolution = unpack_res(ev, field_count)
        res_count = ev.unpack('i')[0]
        @resolutions = res_count.times.collect {|i| unpack_res(ev, field_count) }
        handle = get_method_handle(@focus, :handle_resolution)
        set_resolution(handle.call())

      end

      return true
    end

    def unpack_res(ev, field_count)
      resolution = ev.unpack('iiii')
      if field_count > 4
        ev.unpack('i' * (field_count - 4))
      end
      return resolution
    end

    def get_method_handle(obj, meth)
      if obj.respond_to?(meth)
        obj.method(meth)
      else
        self.method(meth)
      end
    end

    # Send a key event to the TiVo, for it to send back to us
    # later.
    def send_key(keynum, rawcode=0, animation: nil, animtime: 0)
      if animation.nil?
        if animtime > 0
          animation = Animation.new(self, animtime)
        else
          animation = @immediate
        end
      end
      put(CMD_RSRC_SEND_EVENT, 'iiiiii', animation.id, EVT_KEY,
          @id, KEY_PRESS, keynum, rawcode)
      @wfile.flush() rescue nil
    end

    # Set the focus to a new object, and notify both the old and
    # newly focused objects of the change. Define a handle_focus()
    # method for an object if you want it to do something special
    # on a focus change; handle_focus() should take a single
    # boolean parameter, which will be False when losing focus and
    # True when gaining it.
    def set_focus(focus)
      if focus != @focus
        if @focus.respond_to? :handle_focus
          @focus.send(:handle_focus, false)
        end
        @focus = focus
        if focus.respond_to? :handle_focus
          focus.send(:handle_focus, true)
        end
      end
    end

    # Flush the write buffer, then sleep for interval seconds
    def sleep(interval)
      begin
        @wfile.flush()
      rescue
        @active = false
      end
      Kernel.sleep(interval)
    end

    # Shorter form for playing sounds based on the id (the only
    # ones that actually work). Can be specified by name or by
    # number.
    def sound(id=nil)
      names = {
          'bonk' => ID_BONK_SOUND,
          'updown' => ID_UPDOWN_SOUND,
          'thumbsup' => ID_THUMBSUP_SOUND,
          'thumbsdown' => ID_THUMBSDOWN_SOUND,
          'select' => ID_SELECT_SOUND,
          'tivo' => ID_TIVO_SOUND,
          'left' => ID_LEFT_SOUND,
          'right' => ID_RIGHT_SOUND,
          'pageup' => ID_PAGEUP_SOUND,
          'pagedown' => ID_PAGEDOWN_SOUND,
          'alert' => ID_ALERT_SOUND,
          'deselect' => ID_DESELECT_SOUND,
          'error' => ID_ERROR_SOUND,
          'slowdown1' => ID_SLOWDOWN1_SOUND,
          'speedup1' => ID_SPEEDUP1_SOUND,
          'speedup2' => ID_SPEEDUP2_SOUND,
          'speedup3' => ID_SPEEDUP3_SOUND,
          'speedup4' => ID_SPEEDUP4_SOUND
      }
      if id.is_a? String
        id = names[id]
      end
      Sound.new(self, id: id).play()
    end

    # Switch to another HME app.
    # direction is TRANSITION_FORWARD or TRANSITION_BACK. params
    # is a dict of lists -- see pack_dict(). url is the address of
    # the new app -- leave it blank for a backwards transition.
    # memento is a blob of data in unspecified format, limited to
    # 10K. params is meant to pass parameters, while memento is
    # supposed to record the current state of the app, and is
    # passed back unchanged after a TRANSITION_BACK.
    def transition(direction, params, url='', memento='')
      if memento.length > 10240
        raise 'memento too large'
      end
      put(CMD_RECEIVER_TRANSITION, 'sidv',
          url, direction, params, memento)
    end

    # Change the screen resolution.
    # This is called from get_event() after handle_resolution()
    # (see there for more about resolution), but can also be used
    # directly.
    def set_resolution(resolution)
      if (@resolutions.include?(resolution) && resolution != @current_resolution)
          put(CMD_RECEIVER_SET_RESOLUTION, 'iiii', *resolution)
          @current_resolution = resolution
          @root.set_bounds(width: resolution[0],
                           height: resolution[1])
      end
   end

    # Stubs for apps to override.

    # Override this to do any setup of your app before the main event loop
    def startup
    end

    # Override this to handle key presses. (EVT_KEY, KEY_PRESS)
    def handle_key_press(keynum, rawcode=nil)
    end

    # Override this to handle key repeats. (EVT_KEY, KEY_REPEAT)
    def handle_key_repeat(keynum, rawcode=nil)
      handle_key_press(keynum, rawcode)
    end

    # Override this to handle key releases. (EVT_KEY, KEY_RELEASE)
    def handle_key_release(keynum, rawcode=nil)
    end

    # Override this to handle "active = true" from EVT_APP_INFO
    def handle_active
    end

    # Override this to handle errors from EVT_APP_INFO
    def handle_error(code, text)
    end

    # Override this to handle anything else from EVT_APP_INFO
    def handle_app_info(info)
    end

    # Override this to handle EVT_DEVICE_INFO
    def handle_device_info(info)
    end

    # Override this if you want to handle EVT_RSRC_INFO. resource
    # is the resource id number, status is the status code, and
    # info is a dict with whatever else the event returned.
    def handle_resource_info(resource, status, info)
    end

    # Override this if you want to do something on getting an
    # EVT_FONT_INFO event. font is the Font object, with the new
    # details (ascent, descent, height, line_gap, and a glyphs
    # dict) added.
    def handle_font_info(font)
    end

    # If you can handle an idle event, override this, and return
    # True. The idle parameter is True when entering idle mode,
    # and False when leaving.
    def handle_idle(idle)
      return false
    end

    # Override this to handle EVT_INIT_INFO. params and memento
    # are as created by the transition() method in the parent app.
    def handle_init_info(params, memento)
    end

    # Override this if you want to be able to change the screen
    # resolution from its default of 640x480; return the desired
    # resolution (which must be from the allowed list). The
    # allowed resolutions are given in self.resolutions; the
    # current in self.current_resolution. They're in the form of a
    # tuple: (width, height, px, py), where px:py is the pixel
    # aspect ratio.
    def handle_resolution
      return @current_resolution
    end

    # If you need to do any cleanup after you're done handling
    # events, override this and do it here.
    def cleanup
    end

  end

end

module TivoHME

  # The View class
  # A view is the basic unit of the HME display. It has a size,
  # position, and can have an associated resource, which is either a
  # Color (i.e., a background color for the entire area), an Image,
  # or Text. It can also have children -- views within views. For
  # example, the parent view might be set to a background color,
  # with its child displaying text.
  #
  # For this class, position, size, visibility, parent, and an
  # associated resource can be set on initialization; all have
  # default values. Each View maintains a list of child Views,
  # scale, transparency and translation.
  class View < TivoHME::Object

    attr_accessor :xpos, :ypos, :width, :height,
                  :parent, :visible, :children, :resource


    def initialize(app, xpos: 0, ypos: 0, width: nil, height: nil,
                   visible: true, parent: nil, id: nil, resource: nil,
                   text: nil, colornum: nil, image: nil, flags: 0,
                   transparency: 0)

      super(app, id)
      @children = []
      @resource = nil
      @xscale = 1
      @yscale = 1
      @painting = true
      @transparency = 0
      @xtranslation = 0
      @ytranslation = 0

      if id.nil? and parent.nil?
        parent = app.root
      end

      if parent
        if app.nil?
          app = parent.app
        end
        if width.nil?
          width = parent.width - xpos
        end
        if height.nil?
          height = parent.height - ypos
        end
      else
        width, height = app.current_resolution[0...2]
      end

      @xpos = xpos
      @ypos = ypos
      @width = width
      @height = height

      if parent
        put(CMD_VIEW_ADD, 'iiiiib', parent.id, xpos, ypos,
            width, height, visible)
        parent.children << self
      else
        visible = false  # root view starts out not visible
      end

      @parent = parent
      @visible = visible

      if transparency > 0
        set_transparency(transparency)
      end

      if resource
        set_resource(resource, flags)
      elsif text
        set_text(text, flags: flags)
      elsif image
        set_image(image, flags: flags)
      elsif ! colornum.nil?
        set_color(colornum)
      end

    end

    # Change the size and/or shape of the view, optionally over a
    # period of time. The interval can be specified either in
    # number of seconds (animtime=), or as an Animation object
    # (animation=).
    def set_bounds(xpos: nil, ypos: nil, width: nil, height: nil,
                   animation: nil, animtime: 0)
      if xpos.nil?
        xpos = @xpos
      end
      if ypos.nil?
        ypos = @ypos
      end
      if width.nil?
        width = @width
      end
      if height.nil?
        height = @height
      end
      if animation.nil?
        if animtime > 0
          animation = Animation.new(@app, animtime)
        else
          animation = @app.immediate
        end
      end
      put(CMD_VIEW_SET_BOUNDS, 'iiiii', xpos, ypos, width, height,
         animation.id)
      @xpos = xpos
      @ypos = ypos
      @width = width
      @height = height
    end

    # Scale the view up or down, optionally over a period of time
    def set_scale(xscale=nil, yscale=nil, animation: nil,
                  animtime: 0)
      if xscale.nil?
        xscale = @xscale
      end
      if yscale.nil?
        yscale = @yscale
      end
      if animation.nil?
        if animtime > 0
          animation = Animation.new(@app, animtime)
        else
          animation = @app.immediate
        end
      end
      put(CMD_VIEW_SET_SCALE, 'ffi', xscale, yscale,
          animation.id)
      @xscale = xscale
      @yscale = yscale
    end

    # Set the "translation" of the view, optionally over a period
    # of time. What this does is move the contents within the
    # view, while the view itself stays in the same place.
    def set_translation(xtranslation=0, ytranslation=0,
                        animation: nil, animtime: 0)
      if @xtranslation != xtranslation || @ytranslation != ytranslation
        if animation.nil?
          if animtime > 0
            animation = Animation.new(@app, animtime)
          else
            animation = @app.immediate
          end
        end
        put(CMD_VIEW_SET_TRANSLATION, 'iii',
            xtranslation, ytranslation, animation.id)
        @xtranslation = xtranslation
        @ytranslation = ytranslation
      end
    end

    # Translate with relative coordinates, vs. the absolute
    # coordinates used in set_translation().
    def translate(xincrement=0, yincrement=0, animation=nil,
                  animtime=0)
        set_translation(@xtranslation + xincrement,
                        @ytranslation + yincrement,
                        animation, animtime)
    end

    # Change the transparency of the view, optionally over a
    # period of time(i.e., fade in/fade out).
    def set_transparency(transparency, animation: nil, animtime: 0)
      if @transparency != transparency
        if animation.nil?
          if animtime > 0
            animation = Animation.new(@app, animtime)
          else
            animation = @app.immediate
          end
        end
        put(CMD_VIEW_SET_TRANSPARENCY, 'fi',
            transparency, animation.id)
        @transparency = transparency
      end
    end

    # Make the view visible or invisible, optionally after a
    # period of time.
    def set_visible(visible=true, animation: nil, animtime: 0)
      if @visible != visible
        if animation.nil?
          if animtime > 0
            animation = Animation.new(@app, animtime)
          else
            animation = @app.immediate
          end
        end
        put(CMD_VIEW_SET_VISIBLE, 'bi',
            visible, animation.id)
        @visible = visible
      end
    end

    # Set the view to update on screen(painting=true) or not.
    # Use this to perform a series of changes, then make them
    # visible all at once. (painting=false differs from
    # invisibility in that the old contents of the view remain on
    # screen.)
    def set_painting(painting=true)
      if @painting != painting
        put(CMD_VIEW_SET_PAINTING, 'b', painting)
        @painting = painting
      end
    end

    # Set the view's associated resource to a Text, Color or Image
    # object.
    def set_resource(resource, flags=0)
      if @resource != resource
        put(CMD_VIEW_SET_RESOURCE, 'ii', resource.id, flags)
        @resource = resource
      end
    end

    # Disassociate the view from its resource. Does not remove
    # the resource.
    def clear_resource
      if @resource
        put(CMD_VIEW_SET_RESOURCE, 'ii', ID_NULL, 0)
        @resource = nil
      end
    end

    # Remove the view's associated resource
    def remove_resource
      if @resource
        @resource.remove()
        @resource = nil
      end
    end

    # Remove the view, optionally after a period of time
    def remove(animation: nil, animtime: 0)
      if animation.nil?
        if animtime > 0
          animation = Animation.new(@app, animtime)
        else
          animation = @app.immediate
        end
      end
      put(CMD_VIEW_REMOVE, 'i', animation.id)
      if @parent
        @parent.children.delete(self)
      end
    end

    # Set the view's associated resource to the given message
    # text. Font, Color (or colornum) and flags can also be
    # specified, but need not be.
    def set_text(message, font: nil, color: nil, colornum: nil, flags: 0)
      set_resource(Text.new(@app, message, font: font, color: color, colornum: colornum), flags)
    end

    # Set the view's associated resource to the given image data,
    # file object or file name. Flags can be optionally specified.
    def set_image(name=nil, f: nil, data: nil, flags: 0)
      set_resource(Image.new(@app, name: name, f: f, data: data), flags)
    end

    # Set the view's associated resource to the given color
    # number.
    def set_color(colornum=nil)
      set_resource(Color.new(@app, colornum))
    end

    # Create a child View of this one. This is just slightly
    # easier to use than calling the View constructor directly:
    #
    # aview.child(text='Hello')
    #
    # vs.
    #
    # View(self, parent=aview, text='Hello')
    #
    # with the exception of children of the root View, which is
    # the default parent.
    # TODO: fix kwargs
    def child(*args, **kwargs)
      kwargs = {parent: self}.merge(kwargs)
      return View.new(@app, *args, **kwargs)
    end

  end

end

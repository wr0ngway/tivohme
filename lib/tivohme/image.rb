module TivoHME

  # Image resource
  # Specified by data, file object or file name, one of which must
  # be given. Image objects specified by name are cached in the
  # app.images dict.
  class Image < Resource

    def initialize (app, name: nil, f: nil, data: nil)
      @name = name
      if name.nil? and f.nil? and data.nil?
        raise 'No image specified for Image resource'
      end
      if name and app.images.include?(name)
        super(app, app.images[name].id)
      else
        super(app)
        if data.nil?
          if f.nil?
            f = File.open(name, 'rb')
          end
          data = f.read()
        end
        put(CMD_RSRC_ADD_IMAGE, 'r', data)
        if name
          app.images[name] = self
        end
      end
    end

    def remove
      super
      if @name
        @app.images.delete(@name)
      end
    end

    # TODO: need finalizer for ruby
    # ObjectSpace.define_finalizer(self, self.class.method(:finalize).to_proc)
    # def self.finalize(id)
    #   if not @name
    #     Resource.remove(self)
    #   end
    # end

  end

end
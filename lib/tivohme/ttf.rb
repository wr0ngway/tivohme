module TivoHME

  # TrueType font file resource
  # Specified by data, file object, file name or id. If none is
  # given, ID_DEFAULT_TTF is used. TTF objects specified by name are
  # cached in the app.ttfs dict, and the last TTF set is stored in
  # app.last_ttf.
  class TTF < Resource

      def initialize (app, name: nil, f: nil, data: nil, id: nil)
        if name.nil? and f.nil? and data.nil? and id.nil?
          id = ID_DEFAULT_TTF
        end
        @name = name
        if name && app.ttfs.include?(name)
          super(app, app.ttfs[name].id)
        else
          super(app, id)
          if id.nil?
            if data.nil?
              if f.nil?
                f = File.open(name, 'rb')
              end
              data = f.read()
            end
            put(CMD_RSRC_ADD_TTF, 'r', data)
            if name
              app.ttfs[name] = self
            end
          end
        end
        app.last_ttf = self
      end

      def remove
        if @name
          super(self)
          @app.ttfs.delete(@name)
          if @app.last_ttf == self
            @app.last_ttf = nil
          end
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

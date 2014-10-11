require 'builder'
require 'sinatra/base'
require 'dnssd'
require 'active_support/core_ext/string'

module TivoHME
  class Server < Sinatra::Base

    enable :logging
    set :root, File.expand_path("../server", __FILE__)
    set :reload_templates, true
    set :builder, :content_type => 'text/xml'

    class ApplicationAdapter

      attr_reader :name, :title, :resource_path,
                  :uuid, :url, :icon_url, :content_type, :genres

      def initialize(name, title, resource_path, app_class_or_callable)
        @name = name
        @title = title
        @resource_path = resource_path
        @app_class_or_callable = app_class_or_callable
        @uuid = SecureRandom.uuid
        @url = "/#{name}/"
        @icon_url = "/#{name}/icon.png"
        @content_type = TivoHMO::Constants::HME_MIME
        @genres = ['other']
      end

      def new_app(io)
        case @app_class_or_callable
          when Class
            @app_class_or_callable.new(infile: io, outfile: io)
          else
            @app_class_or_callable.call(io)
        end
      end
    end

    class BufferedIO
      def initialize(delegate, write_buf_size)
        @delegate = delegate
        @write_buf_size = write_buf_size
        @buf = ""
      end

      def read(*args)
        @delegate.read(*args)
      end

      def write(data)
        @buf << data
        if @buf.size >= @write_buf_size
          flush
        end
      end

      def flush
        @delegate.write(@buf)
        @delegate.flush
        @buf.clear
      end
    end

    def self.start(apps, port)
      server = new(apps)
      apps.each {|app| broadcast_app(app, port) }
      Rack::Handler.default.run server, Port: port
    end

    def self.broadcast_app(app, port)
      title = app.title.gsub(' ', "\u00A0")
      desc = {'path' => app.url, 'version' => TivoHME::Constants::HME_VERSION }
      text = desc.collect {|k, v| "#{k}=#{v}"}.collect {|s| "#{s.size.chr}#{s}" }.join('')
      DNSSD.register title, '_tivo-hme._tcp', nil, port, text
    end

    def initialize(apps)
      @apps = apps
      super
    end

    helpers do
      include Rack::Utils

      def apps
        @apps
      end
    end

    # Get the xml doc describing the active HME applications
    get '/TiVoConnect' do
      logger.info "Tivo Connected"
      builder :index, layout: true, locals: { show_genres: params['DoGenres'] == 1 }
    end

    # Run the named HME application
    get '/:app_name/?' do
      logger.info "Looking for application #{params[:app_name]}"
      app = @apps.find {|a| a.name == params[:app_name] }
      if app
        logger.info "Running application #{app.name}"

        env['rack.hijack'].call
        io = env['rack.hijack_io']

        # makes it easier to compare the bytes sent with ngrep
        io = BufferedIO.new(io, 0x10000)

        # io.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDBUF, 0x10000)
        # io.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVBUF, 0x10000)

        buf = ""
        buf << "HTTP/1.0 200 OK\r\n"
        buf << "Content-Type: #{app.content_type}\r\n"
        buf << "\r\n"
        io.write(buf)

        begin
          hme_app = app.new_app(io)
          hme_app.context = {'url' => request.url}
          hme_app.mainloop
        rescue => e
          logger.error("Exception whilst running HME application #{app.name}: [#{e.class}] #{e.message}")
          logger.error(e.backtrace.join("\n")) if e.backtrace
        end
      else
        halt 404, "No application found for #{params[:app_name]}"
      end
    end

    # Get resources belonging to the named HME application
    get '/:app_name/*' do
      logger.info "Looking for resource for application #{params[:app_name]}"
      app = @apps.find {|a| a.name == params[:app_name] }
      if app
        resource_path = params[:splat].first
        logger.info "Returning #{app.name} resource: #{resource_path}"
        path = File.expand_path(resource_path, app.resource_path)
        if path && path.start_with?(app.resource_path)
          send_file path
        else
          halt 404, "Invalid resource path: #{path}"
        end
      else
        halt 404, "No application found for #{params[:app_name]}"
      end
    end

    get "/*" do
      p params[:splat]
    end
  end
end

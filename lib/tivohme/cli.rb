require 'clamp'
require 'active_support/core_ext/string'

module TivoHME

  class CLI < Clamp::Command

    include GemLogger::LoggerSupport

    def self.description
      "Runs the given HME applications"
    end

    option ["-d", "--debug"],
           :flag, "debug output\n",
           :default => false

    option ["-p", "--port"],
           "PORT", "run server using PORT\n",
           :default => 9142

    option ["-s", "--samples"],
           :flag, "run all the sample applications\n",
           :default => false

    option ["-a", "--application"],
           "APPDIR", "run the application in APPDIR\n",
           :multivalued => true

    def execute
      GemLogger.default_logger.level = debug? ? Logger::DEBUG : Logger::INFO

      app_dirs = []

      if samples?
        sample_root = File.expand_path("../samples", __FILE__)
        Dir["#{sample_root}/*"].each do |app_dir|
          app_dirs << app_dir if File.directory?(app_dir)
        end
      end

      application_list.each do |app_dir|
        app_dirs << app_dir if File.directory?(app_dir)
      end

      apps = []
      app_dirs.each do |app_dir|
        begin
          apps << create_app(app_dir)
        rescue Exception => e
          logger.error "Could not create an application for '#{app_dir}'"
          logger.error e
        end
      end
      TivoHME::Server.start(apps, port)
    end

    private

    def create_app(dir)
      mod = Module.new

      Dir["#{dir}/*.rb"].each do |rb|
        mod.module_eval(File.read(rb), rb)
      end

      app_class = nil
      mod.constants.each do |const|
        const_value = mod.const_get(const)
        if const_value.is_a?(Class) && const_value.ancestors.include?(TivoHME::Application)
          app_class = const_value
          break
        end
      end
      raise "No application class defined in #{dir}" unless app_class

      name = File.basename(dir)
      title = mod.const_defined?(:TITLE) ? mod.const_get(:TITLE) : name.titleize

      logger.info "Registering application '#{name}', class: #{app_class.name.demodulize}, title: '#{title}'"
      new_app = ->(io) { app_class.new(infile: io, outfile: io) }
      adapter = TivoHME::Server::ApplicationAdapter.new(name, title, dir, new_app)
      adapter
    end
  end

end

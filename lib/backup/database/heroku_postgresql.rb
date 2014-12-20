# encoding: utf-8

module Backup
  module Database
    class HerokuPostgreSQL < Base
      class Error < Backup::Error; end

      ##
      # Name of the application whose database needs to get dumped by pgbackups
      attr_accessor :name

      ##
      # Additional heroku toolbelt options
      attr_accessor :additional_options

      def initialize(model, database_id = nil, &block)
        super
        instance_eval(&block) if block_given?
      end

      ##
      # Performs the mysqldump command and outputs the dump file
      # in the +dump_path+ using +dump_filename+.
      #
      #   <trigger>/databases/PostgreSQL[-<database_id>].sql[.gz]
      def perform!
        super

        pipeline = Pipeline.new
        dump_ext = 'dump'

        pipeline << capture_and_download_backup(@name, "'#{ File.join(dump_path, dump_filename) }.#{ dump_ext }'")

        model.compressor.compress_with do |command, ext|
          pipeline << command
          dump_ext << ext
        end if model.compressor
        
        pipeline << "#{ utility(:cat) } > " +
            "'#{ File.join(dump_path, dump_filename) }.#{ dump_ext }'"

        pipeline.run
        if pipeline.success?
          log!(:finished)
        else
          raise Error, "Dump Failed!\n" + pipeline.error_messages
        end
      end

      # backup_url is a lambda so it gets executed at proper time (pipeline execution time rather than pipeline creation time)
      # TODO maybe pipeline already has a mechanism to separate this into two pipeline steps, but didn't investigate
      # TODO if possible separate into multiple pipeline steps
      def capture_and_download_backup(app_name, where_to_put_it)
        backup_url = lambda {
          # See https://github.com/sstephenson/rbenv/issues/400
          Bundler.with_clean_env {
            `heroku pgbackups:capture --expire --app #{app_name}`  
            `heroku pgbackups:url --app #{app_name}`[0..-2]  # heroku returns the URL with a \n at the end  
          }          
        }
        "wget --quiet --output-document #{where_to_put_it} \"#{backup_url.call}\""
      end      

      def password_option
        "PGPASSWORD='#{ password }' " if password
      end

      def username_option
        "--username='#{ username }'" if username
      end

      #attr_deprecate :utility_path, :version => '3.0.21',
      #    :message => 'Use Backup::Utilities.configure instead.',
      #    :action => lambda {|klass, val|
      #      Utilities.configure { pg_dump val }
      #    }

    end
  end
end

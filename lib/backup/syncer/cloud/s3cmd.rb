# encoding: utf-8
require 'backup/cloud_io/s3'

module Backup
  module Syncer
    module Cloud
      class S3cmd < Base
        class Error < Backup::Error; end

        ## 
        # SSH settings, if calling s3cmd on a remote host
        attr_accessor :ssh_user, :ssh_host, :use_ssh
                
        ##
        # S3cmd config file and destination path (either local or remote, depending on ssh)
        attr_accessor :destination_path, :config_file

        ##
        # Amazon S3 bucket name
        attr_accessor :bucket

        def initialize(syncer_id = nil)
          super

          check_configuration
        end
        
        def perform!                  
          command = "s3cmd -c #{config_file} --verbose --recursive sync s3://#{bucket}/ #{destination_path}"
          command = "ssh #{ssh_user}@#{ssh_host} #{command}" if use_ssh
          `#{command}`
        end

        private

        def check_configuration
          if use_ssh
            required = %w{ ssh_user ssh_host bucket destination_path }
          else
            required = %w{ bucket destination_path }
          end
          raise Error, <<-EOS if required.map {|name| send(name) }.any?(&:nil?)
            Configuration Error
            #{ required.map {|name| "##{ name }"}.join(', ') } are all required
          EOS
        end

      end # Class S3cmd < Base
    end # module Cloud
  end
end

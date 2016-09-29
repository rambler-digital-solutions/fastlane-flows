require 'net/ftp'

module Fastlane
  module Actions

    class RdsFtpClientAction < Action
      def self.run(params)
        UI.message "Starting upload to FTP"

        @file_paths = params[:file_paths]
        @ftp_root_dir = params[:ftp_root_dir]

        @ftp_host = params[:ftp_host]
        @ftp_port = params[:ftp_port]
        @ftp_user = params[:ftp_user]
        @ftp_password = params[:ftp_password]

        connect_to_ftp
        upload_files
      end

      def self.connect_to_ftp
        @ftp = Net::FTP.new
        @ftp.passive = true
        @ftp.connect(@ftp_host, @ftp_port)

        if @ftp_user.to_s == ''
          @ftp.login
        else
          @ftp.login(@ftp_user, @ftp_password)
        end
      end

      def self.upload_files
        @file_paths.each { |file_path|
          source_path = file_path[:source_path]
          destination_path = Pathname(@ftp_root_dir).join(file_path[:destination_path])

          root_path = Pathname(@ftp_root_dir)
          path_components = destination_path.dirname.to_s.split('/')

          path_components.each { |path|
            root_path = root_path.join(path)
            @ftp.mkdir(root_path.to_s) rescue ''
          }

          @ftp.putbinaryfile(source_path, destination_path.to_s)
        }

        @ftp.close
      end

      def self.description
        "This action uploads an files to FTP server"
      end

      def self.available_options
        [
            FastlaneCore::ConfigItem.new(key: :file_paths,
                                         env_name: "RDS_FTP_CLIENT_IPA_PATH",
                                         description: "Array with paths to files. Example: [{:source_path => 'path/to/source_file', :destination_path => 'path/to/destination_file'}]",
                                         type: Array),
            FastlaneCore::ConfigItem.new(key: :ftp_root_dir,
                                         env_name: "RDS_FTP_CLIENT_ROOT_DIR",
                                         description: "FTP root dir",
                                         optional: true,
                                         default_value: '',
                                         type: String),
            FastlaneCore::ConfigItem.new(key: :ftp_host,
                                         env_name: "RDS_FTP_CLIENT_HOST",
                                         description: "FTP host",
                                         type: String),
            FastlaneCore::ConfigItem.new(key: :ftp_port,
                                         env_name: "RDS_FTP_CLIENT_PORT",
                                         description: "FTP port",
                                         optional: true,
                                         type: String),
            FastlaneCore::ConfigItem.new(key: :ftp_user,
                                         env_name: "RDS_FTP_CLIENT_USER",
                                         description: "FTP user",
                                         optional: true,
                                         type: String),
            FastlaneCore::ConfigItem.new(key: :ftp_password,
                                         env_name: "RDS_FTP_CLIENT_PASSWORD",
                                         description: "FTP password",
                                         optional: true,
                                         type: String)
        ]
      end

      def self.authors
        ["Beniamiiin"]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end

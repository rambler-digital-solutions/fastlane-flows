require 'net/ftp'
require 'json'
require 'tempfile'

FTP_ROOT_DIR = "/www"

FTP_BUILDS_FILE = "builds.json"
FTP_PROJECTS_FILE = "projects.json"

TEMPLATE_PLIST_FILENAME = 'template.plist'

module Fastlane
  module Actions
    module SharedValues
      RDS_FTP_DEPLOY_CUSTOM_VALUE = :RDS_FTP_DEPLOY_CUSTOM_VALUE
    end
    class RdsFtpDeployAction < Action
      def self.run(params)
        UI.message "Starting FTP deploy"
        @ipa_path = params[:ipa_path]
        @app_identifier = params[:app_identifier]
        @name = params[:name]
        @build_version = params[:build_version]
        @baseurl = Pathname(params[:baseurl]).join(params[:ftp_path])
        @ftp_dir = FTP_ROOT_DIR + "/#{params[:ftp_path]}"

        @ftp_host = params[:ftp_host]
        @ftp_port = params[:ftp_port]
        @ftp_user = params[:ftp_user]
        @ftp_password = params[:ftp_password]

        # Подключаемся к серверу
        connect_to_ftp
        create_server_structure_if_needed

        @build_date = Date.today.to_s
        @build_folder_name = get_build_folder_name
        @plist_name = "#{File.basename(@ipa_path, ".ipa")}.plist"
        @plist_url = "#{@app_identifier}/#{@build_folder_name}/#{@plist_name}"


        # Загружаем билд
        upload_build
        # Добавляем запись о билде
        upload_build_info
        # Добавляем запись о проекте
        upload_project_info

      end

      # Формат названия папки {дата}
      def self.get_build_folder_name
        "#{Date.today.to_s}"
      end

      def self.create_server_structure_if_needed
        @ftp.chdir(@ftp_dir)
        files = @ftp.nlst

        # Если нет файла списка проектов, создаем структуру с нуля
        create_new_structure unless files.include?(FTP_PROJECTS_FILE)

        # Если папки нет, создаем структуру папок/файлов для нового приложения
        create_new_app_structure unless files.include?(@app_identifier)
      end

      def self.create_new_structure
        @ftp.chdir(@ftp_dir)

        projects_file = Tempfile.new('foo')
        begin
          projects = []
          projects_file.write(projects.to_json)
          projects_file.rewind
          @ftp.putbinaryfile(projects_file.path, FTP_PROJECTS_FILE)
        ensure
          projects_file.close
          projects_file.unlink   # deletes the temp file
        end
      end

      def self.upload_build
        # Переходим в папку проекта
        @ftp.chdir(@ftp_dir)
        @ftp.chdir(@app_identifier)

        # Создаем и переходим в папку билда
        files = @ftp.nlst
        UI.message "FTP folder name: #{@build_folder_name}"
        remove_folder if files.include?(@build_folder_name)

        @ftp.mkdir(@build_folder_name)
        @ftp.chdir(@build_folder_name)

        # Загружаем билд
        @ftp.putbinaryfile(@ipa_path)

        # Генерируем правильный plist и загружаем на сервер
        plist_file = Tempfile.new('plist_file')
        begin
          relative_path = "#{@app_identifier}/#{@build_folder_name}/#{File.basename(@ipa_path)}"
          url = Pathname(@baseurl).join(relative_path).to_s
          plist = FTP_TEMPLATE_PLIST % {:url => url,
                                    :bundle_identifier => @app_identifier,
                                    :bundle_version => @build_version,
                                    :title => @name}

          plist_file.write(plist)
          plist_file.rewind

          @ftp.putbinaryfile(plist_file.path, @plist_name)
        ensure
          plist_file.close
          plist_file.unlink # deletes the temp file
        end
      end

      def self.remove_folder
        @ftp.nlst(@build_folder_name).each do |file|
          UI.message "Deleting file: #{file}"
          @ftp.delete("#{file}")
        end
        @ftp.rmdir(@build_folder_name)
      end


      def self.upload_build_info
        # Переходим в папку проекта
        @ftp.chdir(@ftp_dir)
        @ftp.chdir(@app_identifier)

        # Загружаем на сервер
        builds_file_remote = Tempfile.new('builds_file_remote')
        builds_file_local = Tempfile.new('builds_file_local')

        begin
          @ftp.getbinaryfile(FTP_BUILDS_FILE, builds_file_remote.path)
          builds = JSON.parse(builds_file_remote.read)
          builds.delete_if { |build| build['uploaded_at'] == @build_date }

          build = {'build_version': @build_version, 'uploaded_at': @build_date, 'plist_url': @plist_url}
          builds.push(build)

          builds_file_local.write(builds.to_json)
          builds_file_local.rewind

          @ftp.putbinaryfile(builds_file_local.path, FTP_BUILDS_FILE)
        ensure
          builds_file_remote.close
          builds_file_remote.unlink
          builds_file_local.close
          builds_file_local.unlink
        end
      end

      def self.upload_project_info
        @ftp.chdir(@ftp_dir)

        # Загружаем на сервер
        projects_file_remote = Tempfile.new('projects_file_remote')
        projects_file_local = Tempfile.new('projects_file_local')

        begin
          @ftp.getbinaryfile(FTP_PROJECTS_FILE, projects_file_remote.path)
          projects = JSON.parse(projects_file_remote.read)

          projects.delete_if { |project| project['app_identifier'] == @app_identifier }

          project =  {'app_identifier':@app_identifier,
                      'name':@name,
                      'build_version': @build_version,
                      'uploaded_at': @build_date,
                      'plist_url': @plist_url}

          projects.push(project)

          projects_file_local.write(projects.to_json)
          projects_file_local.rewind

          @ftp.putbinaryfile(projects_file_local.path, FTP_PROJECTS_FILE)
        ensure
          projects_file_remote.close
          projects_file_remote.unlink
          projects_file_local.close
          projects_file_local.unlink
        end
      end

      def self.connect_to_ftp
        @ftp = Net::FTP.new
        @ftp.passive = true
        @ftp.connect(@ftp_host, @ftp_port)
        @ftp.login(@ftp_user, @ftp_password)
      end


      def self.create_new_app_structure
        @ftp.chdir(@ftp_dir)
        @ftp.mkdir(@app_identifier)
        @ftp.chdir(@app_identifier)

        builds_file = Tempfile.new('foo')
        begin
          builds = []
          builds_file.write(builds.to_json)
          builds_file.rewind
          @ftp.putbinaryfile(builds_file.path, FTP_BUILDS_FILE)
        ensure
          builds_file.close
          builds_file.unlink 
        end
      end

      def upload_ipa

      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "This action uploads an ipa file to RDS FTP server"
      end

      def self.available_options
        [
            FastlaneCore::ConfigItem.new(key: :ipa_path,
                                         env_name: "FL_RDS_FTP_DEPLOY_IPA_PATH",
                                         description: "Path to ipa file",
                                         is_string: true),
            FastlaneCore::ConfigItem.new(key: :app_identifier,
                                         env_name: "FL_RDS_FTP_DEPLOY_APP_IDENTIFIER",
                                         description: "Bundle id",
                                         is_string: true),
            FastlaneCore::ConfigItem.new(key: :name,
                                         env_name: "FL_RDS_FTP_DEPLOY_NAME",
                                         description: "Application name",
                                         is_string: true),
            FastlaneCore::ConfigItem.new(key: :build_version,
                                         env_name: "FL_RDS_FTP_DEPLOY_BUILD_VERSION",
                                         description: "Build version",
                                         is_string: true),
            FastlaneCore::ConfigItem.new(key: :baseurl,
                                         env_name: "FL_RDS_FTP_DEPLOY_BASEURL",
                                         description: "Baseurl",
                                         is_string: true),
            FastlaneCore::ConfigItem.new(key: :ftp_path,
                                         env_name: "FL_RDS_FTP_DEPLOY_PATH",
                                         description: "FTP path",
                                         is_string: true)
        ]
      end

      def self.output
        [
            ['RDS_FTP_DEPLOY_CUSTOM_VALUE', 'A description of what this value contains']
        ]
      end

      def self.authors
        ["Herman Saprykin"]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end

FTP_TEMPLATE_PLIST='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>items</key>
	<array>
		<dict>
			<key>assets</key>
			<array>
				<dict>
					<key>kind</key>
					<string>software-package</string>
					<key>url</key>
					<string>%{url}</string>
				</dict>
			</array>
			<key>metadata</key>
			<dict>
				<key>bundle-identifier</key>
				<string>%{bundle_identifier}</string>
				<key>bundle-version</key>
				<string>%{bundle_version}</string>
				<key>kind</key>
				<string>software</string>
				<key>title</key>
				<string>%{title}</string>
			</dict>
		</dict>
	</array>
</dict>
</plist>'
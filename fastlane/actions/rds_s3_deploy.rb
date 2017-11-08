require 'aws-sdk'
require 'json'
require 'tempfile'

S3_MAIN_HTML_FILE = "index.html"
S3_BUILDS_FILE = "builds.json"
S3_PROJECTS_FILE = "projects.json"

TEMPLATE_PROJECTS_HTML_FILENAME = 'fastlane/assets/projects_index_template.html'
TEMPLATE_PROJECT_HTML_FILENAME = 'fastlane/assets/project_index_template.html'
TEMPLATE_PROJECT_PLIST_FILENAME = 'fastlane/assets/project_plist_template.plist'

module Fastlane
  module Actions
    class RdsS3DeployAction < Action

      def self.run(params)
        @ipa_path = params[:ipa_path]
        @app_identifier = params[:app_identifier]
        @app_name = params[:app_name].gsub(" ", "_")
        @build_version = params[:build_version]
        @changelog = params[:changelog]
        @single_page = params[:single_page]
        @base_url = params[:base_url]
        @region = params[:region]
        @access_key = params[:access_key]
        @secret_access_key = params[:secret_access_key]
        @bucket = params[:bucket]

        connect_to_s3
        create_bucket_if_needed
        create_server_structure_if_needed

        @build_date = Time.now.strftime("%d-%m-%Y %H:%M")
        @build_folder_name = Date.today.to_s
        
        full_build_folder_name = "#{@app_name}/#{@build_folder_name}"
        
        @html_name = "#{File.basename(@ipa_path, ".ipa")}.html"
        @html_url = URI.parse(URI.encode("#{full_build_folder_name}/#{@html_name}"))
        
        @plist_name = "#{File.basename(@ipa_path, ".ipa")}.plist"
        @plist_url = URI.parse(URI.encode("#{full_build_folder_name}/#{@plist_name}"))
        
        @ipa_name = File.basename(@ipa_path)
        @ipa_url = URI.parse(URI.encode("#{full_build_folder_name}/#{@ipa_name}"))

        upload_build
        upload_build_info
        upload_project_info

        UI.success("Билд успешно загружен, его можно найти по ссылке: #{@bucket_index_page_url}") if @bucket_index_page_url != nil
      end

      def self.connect_to_s3
        credentials = Aws::Credentials.new(@access_key, @secret_access_key)

        @s3_client = Aws::S3::Client.new(
            region: @region,
            credentials: credentials
        )

        Aws.config.update(
            region: @region,
            credentials: credentials
        )
      end
      
      def self.create_bucket_if_needed
        begin
          @s3_client.head_bucket(
               bucket: @bucket
          )
        rescue Aws::S3::Errors::NotFound
          @s3_client.create_bucket(
              bucket: @bucket
          )
          
          main_html_file = Tempfile.new('main_html_file')
          
          main_html_template = IO.read(File.absolute_path(TEMPLATE_PROJECTS_HTML_FILENAME))
          
          main_html_file.write(main_html_template)
          main_html_file.rewind

          @s3_client.put_object(
              bucket: @bucket,
              key: S3_MAIN_HTML_FILE,
              body: main_html_file,
              acl: 'public-read'
          )
        rescue Aws::S3::Errors::Forbidden
          raise RuntimeError, "Bucket с именем '#{@bucket}' уже существует"
        end

        resource = Aws::S3::Resource.new
        bucket = resource.bucket(@bucket)
        @bucket_index_page_url = bucket.object(S3_MAIN_HTML_FILE).public_url
      end
      
      def self.create_server_structure_if_needed
        files = self.files_list

        # Если нет файла списка проектов, создаем структуру с нуля
        create_new_structure unless files.include?(S3_PROJECTS_FILE)

        # Если папки нет, создаем структуру папок/файлов для нового приложения
        create_new_app_structure unless files.include?(@app_name)
      end

      def self.create_new_structure
        projects_file = Tempfile.new('foo')

        begin
          projects_file.write([].to_json)
          projects_file.rewind

          @s3_client.put_object(
              bucket: @bucket,
              key: S3_PROJECTS_FILE,
              body: projects_file,
              acl: 'public-read'
          )
        ensure
          projects_file.close
          projects_file.unlink
        end
      end

      def self.create_new_app_structure
        builds_file = Tempfile.new('foo')

        begin
          builds_file.write([].to_json)
          builds_file.rewind

          builds_file_url = self.builds_file_url

          @s3_client.put_object(
              bucket: @bucket,
              key: builds_file_url,
              body: builds_file,
              acl: 'public-read'
          )
        ensure
          builds_file.close
          builds_file.unlink
        end
      end

      def self.remove_folder
        @s3_client.delete_object(
            bucket: @bucket,
            key: @build_folder_name
        )
      end

      def self.upload_build
        files = self.files_list

        remove_folder if files.include?(@build_folder_name)

        @s3_client.put_object(
            bucket: @bucket,
            key: @ipa_url.path,
            body: open(@ipa_path),
            acl: 'public-read'
        )

        begin
          html_file = Tempfile.new('html_file')
          plist_file = Tempfile.new('plist_file')

          plist_url = URI.join(@base_url, @plist_url)

          html_template = IO.read(File.absolute_path(TEMPLATE_PROJECT_HTML_FILENAME))
          html = html_template % {:url => plist_url, :name => @app_name, :bundle_version => @build_version}

          html_file.write(html)
          html_file.rewind

          @s3_client.put_object(
              bucket: @bucket,
              key: @html_url.path,
              body: html_file,
              acl: 'public-read'
          )

          ipa_url = URI.join(@base_url, @ipa_url)

          plist_template = IO.read(File.absolute_path(TEMPLATE_PROJECT_PLIST_FILENAME))
          plist = plist_template % {:url => ipa_url,
                                    :bundle_identifier => @app_identifier,
                                    :bundle_version => @build_version,
                                    :title => @app_name,
                                    :changelog => @changelog}

          plist_file.write(plist)
          plist_file.rewind

          @s3_client.put_object(
              bucket: @bucket,
              key: @plist_url.path,
              body: plist_file,
              acl: 'public-read'
          )
        ensure
          plist_file.close
          plist_file.unlink
        end
      end

      def self.upload_build_info
        begin
          builds_file_remote = Tempfile.new('builds_file_remote')
          builds_file_local = Tempfile.new('builds_file_local')

          builds_file_url = self.builds_file_url

          @s3_client.get_object(
              response_target: builds_file_remote.path,
              bucket: @bucket,
              key: builds_file_url
          )

          builds = JSON.parse(builds_file_remote.read)
          builds.delete_if { |build| build['uploaded_at'] == @build_date }

          build = {'build_version': @build_version, 'uploaded_at': @build_date, 'plist_url': @plist_url}
          builds.push(build)

          builds_file_local.write(builds.to_json)
          builds_file_local.rewind

          @s3_client.put_object(
              bucket: @bucket,
              key: builds_file_url,
              body: builds_file_local,
              acl: 'public-read'
          )
        ensure
          builds_file_remote.close
          builds_file_remote.unlink
          builds_file_local.close
          builds_file_local.unlink
        end
      end

      def self.upload_project_info
        projects_file_remote = Tempfile.new('projects_file_remote')
        projects_file_local = Tempfile.new('projects_file_local')

        begin
          @s3_client.get_object(
              response_target: projects_file_remote,
              bucket: @bucket,
              key: S3_PROJECTS_FILE
          )

          projects = JSON.parse(projects_file_remote.read)
          projects.delete_if { |project| project['name'] == @app_name }

          html_url = URI.join(@base_url, @html_url)

          project =  {'app_identifier': @app_identifier,
                      'name': @app_name,
                      'build_version': @build_version,
                      'uploaded_at': @build_date,
                      'plist_url': @plist_url,
                      'html_url': html_url,
                      'single_page': @single_page}

          projects.push(project)

          projects_file_local.write(projects.to_json)
          projects_file_local.rewind

          @s3_client.put_object(
              bucket: @bucket,
              key: S3_PROJECTS_FILE,
              body: projects_file_local,
              acl: 'public-read'
          )
        ensure
          projects_file_remote.close
          projects_file_remote.unlink
          projects_file_local.close
          projects_file_local.unlink
        end
      end

      private

      def self.files_list
        files = []

        @s3_client.list_objects(
            bucket: @bucket
        ).contents.each { |file|
            file_name = file.key

            if file_name.include?('/')
              file_name = file_name.split('/')[0]
            end

            files.push(file_name)
        }

        files
      end

      def self.builds_file_url
        builds_file_url = URI.join(@base_url, URI.encode("#{@app_name}/#{S3_BUILDS_FILE}"))
        return builds_file_url.path.clone[1..-1]
      end

      def self.description
        "Action for upload builds to amazon s3 service"
      end

      def self.available_options
        [
            FastlaneCore::ConfigItem.new(key: :ipa_path,
                                         env_name: "RDS_S3_IPA_PATH",
                                         description: "Path to ipa file",
                                         is_string: true,
                                         default_value: Actions.lane_context[SharedValues::IPA_OUTPUT_PATH]),
            FastlaneCore::ConfigItem.new(key: :app_identifier,
                                         env_name: "RDS_S3_APP_IDENTIFIER",
                                         description: "Bundle id",
                                         is_string: true,
                                         default_value: CredentialsManager::AppfileConfig.try_fetch_value(:app_identifier)),
            FastlaneCore::ConfigItem.new(key: :app_name,
                                         env_name: "RDS_S3_APP_NAME",
                                         description: "Application name",
                                         is_string: true),
            FastlaneCore::ConfigItem.new(key: :build_version,
                                         env_name: "RDS_S3_BUILD_VERSION",
                                         description: "Build version",
                                         is_string: true),
            FastlaneCore::ConfigItem.new(key: :changelog,
                                         env_name: "RDS_S3_CHANGELOG",
                                         description: "Changelog",
                                         is_string: true,
                                         optional: true),
            FastlaneCore::ConfigItem.new(key: :single_page,
                                         env_name: "RDS_S3_SINGLE_PAGE",
                                         description: "Project has need single page",
                                         type: TrueClass,
                                         optional: true,
                                         default_value: false),
            FastlaneCore::ConfigItem.new(key: :base_url,
                                         env_name: "RDS_S3_BASEURL",
                                         description: "Baseurl",
                                         is_string: true,
                                         default_value: ENV['RDS_S3_BASEURL']),
            FastlaneCore::ConfigItem.new(key: :region,
                                         env_name: "RDS_S3_REGION",
                                         description: "Region",
                                         is_string: true,
                                         optional: true,
                                         default_value: ENV['RDS_S3_REGION']),
            FastlaneCore::ConfigItem.new(key: :access_key,
                                         env_name: "RDS_S3_ACCESS_KEY",
                                         description: "S3 Access Key",
                                         is_string: true,
                                         default_value: ENV['RDS_S3_ACCESS_KEY']),
            FastlaneCore::ConfigItem.new(key: :secret_access_key,
                                         env_name: "RDS_S3_SECRET_ACCESS_KEY",
                                         description: "S3 Secret access key",
                                         is_string: true,
                                         default_value: ENV['RDS_S3_SECRET_ACCESS_KEY']),
            FastlaneCore::ConfigItem.new(key: :bucket,
                                         env_name: "RDS_S3_BUCKET",
                                         description: "S3 Bucket",
                                         is_string: true,
                                         default_value: ENV['RDS_S3_BUCKET']),
        ]
      end

      def self.authors
        ["beniamiiin"]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end

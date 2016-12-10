require 'yaml'

module Fastlane
  module Actions

    class RdsOclintAction < Action
      OCLINT_ASSETS_DIRECTORY_PATH = 'fastlane/assets/oclint'
      OCLINT_CONFIG_FILE = 'oclint_config.yml'
      OCLINT_REPORT_TEMPLATE_FILE = 'oclint_html_report_template.html'

      def self.run(params)
        UI.message "Starting OCLint action"

        prepare_variables(params)
        download_oclint_assets
        analyze_project
        upload_reports
        clear_oclint_tmp

        UI.message "Successfully completed OCLint action"
      end

      def self.prepare_variables(params)
        UI.message "Prepare variables"

        @compile_commands_file_path = params[:compile_commands_file_path]
        @project_reports_directory_path = params[:project_reports_directory_path]
        @general_reports_diretory_path = params[:general_reports_diretory_path]
        @application_name = params[:application_name]
        @ftp_host = params[:ftp_host]
        @ftp_port = params[:ftp_port]
        @ftp_user = params[:ftp_user]
        @ftp_password = params[:ftp_password]
      end

      def self.download_oclint_assets
        UI.message "Download OCLint assets"

        oclint_assets_repository_url = 'https://github.com/rambler-ios/fastlane-flows.git'
        clone_folder = oclint_assets_repository_url.split('/').last

        @has_oclint_config = File.exist?(oclint_config_path)
        @has_oclint_report_template = File.exist?(oclint_html_report_template_path)

        uploaded_oclint_config_path = "#{clone_folder}/#{OCLINT_ASSETS_DIRECTORY_PATH}/#{OCLINT_CONFIG_FILE}"
        uploaded_oclint_html_report_file_path = "#{clone_folder}/#{OCLINT_ASSETS_DIRECTORY_PATH}/#{OCLINT_REPORT_TEMPLATE_FILE}"

        FileUtils.rm_rf(clone_folder)
        sh "git clone -b rds_oclint_action #{oclint_assets_repository_url} #{clone_folder}"
        FileUtils.mkdir_p(oclint_assets_path)
        FileUtils.cp(uploaded_oclint_config_path, oclint_assets_path) unless @has_oclint_config
        FileUtils.cp(uploaded_oclint_html_report_file_path, oclint_assets_path) unless @has_oclint_report_template
        FileUtils.rm_rf(clone_folder)
      end

      def self.analyze_project
        UI.message "Analyze project"

        FileUtils.rm_rf(oclint_tmp_dir_path)
        FileUtils.mkdir(oclint_tmp_dir_path)

        oclint_config = YAML.load_file(oclint_config_path)

        rule_configurations = []
        oclint_config['rule-configurations'].map { |rc| rule_configurations.push("#{rc['key']}=#{rc['value']}") }

        Actions::OclintAction.run(
          oclint_path: '/usr/local/bin/oclint',
          compile_commands: @compile_commands_file_path,
          report_path: oclint_json_report_path,
          exclude_regex: Regexp.new(Regexp.escape(oclint_config['exclude_regex'])),
          report_type: oclint_config['report_type'],
          max_priority_1: oclint_config['max-priority-1'],
          max_priority_2: oclint_config['max-priority-2'],
          max_priority_3: oclint_config['max-priority-3'],
          thresholds: rule_configurations,
          enable_rules: oclint_config['rules'],
          list_enabled_rules: oclint_config['list_enabled_rules']
        )
      end

      def self.upload_reports
        UI.message "Upload reports"

        Actions::RdsFtpClientAction.run(
          file_paths: file_paths_for_upload,
          ftp_root_dir: 'www',
          ftp_host: @ftp_host,
          ftp_port: @ftp_port,
          ftp_user: @ftp_user,
          ftp_password: @ftp_password
        )
      end

      def self.clear_oclint_tmp
        UI.message "Clear OCLint tmp"

        FileUtils.rm_rf(oclint_tmp_dir_path)
        FileUtils.rm_rf(@compile_commands_file_path)
        FileUtils.rm_rf(oclint_config_path) unless @has_oclint_config
        FileUtils.rm_rf(oclint_html_report_template_path) unless @has_oclint_report_template
        FileUtils.rm_rf(oclint_assets_path) if !@has_oclint_config && !@has_oclint_report_template
      end

      def self.file_paths_for_upload
        destination_path_base = "#{@project_reports_directory_path}/#{Time.now.strftime("%Y-%m-%d")}"
        general_destination_path_base = "#{@general_reports_diretory_path}/#{@application_name}"

        file_paths = []

        destination_path = "#{destination_path_base}/#{oclint_json_report_name}"
        general_destination_path = "#{general_destination_path_base}.json"

        file_paths.push({
          :source_path => oclint_json_report_path,
          :destination_path => destination_path
        })

        file_paths.push({
          :source_path => oclint_json_report_path,
          :destination_path => general_destination_path
        })

        destination_path = "#{destination_path_base}/#{oclint_html_report_name}"
        general_destination_path = "#{general_destination_path_base}.html"

        file_paths.push({
          :source_path => oclint_html_report_template_path,
          :destination_path => destination_path
        })

        file_paths.push({
          :source_path => oclint_html_report_template_path,
          :destination_path => general_destination_path
        })

        file_paths
      end

      def self.oclint_config_path
        "#{oclint_assets_path}/#{OCLINT_CONFIG_FILE}"
      end

      def self.oclint_html_report_template_path
        "#{oclint_assets_path}/#{OCLINT_REPORT_TEMPLATE_FILE}"
      end

      def self.oclint_json_report_path
        "#{oclint_tmp_dir_path}/#{oclint_json_report_name}"
      end

      def self.oclint_json_report_name
        'oclint_report.json'
      end

      def self.oclint_html_report_name
        'oclint_report.html'
      end

      def self.oclint_assets_path
        "#{fastlane_directory_absolute_path}/assets/oclint"
      end

      def self.oclint_tmp_dir_path
        "#{fastlane_directory_absolute_path}/oclint-tmp"
      end

      def self.fastlane_directory_absolute_path
        File.dirname(File.expand_path(FastlaneCore::FastlaneFolder.fastfile_path))
      end

      def self.description
        "This action run the static analyzer tool OCLint for your project. You need to have a compile_commands.json file in your fastlane directory or pass a path to your file"
      end

      def self.available_options
        [
            FastlaneCore::ConfigItem.new(key: :compile_commands_file_path,
                                         env_name: "RDS_OCLINT_COMPILE_COMMANDS_FILE_PATH",
                                         description: "Path to your compile_commands.json file. If you don't pass path to your file, then file need be have in your fastlane directory",
                                         default_value: 'compile_commands.json',
                                         optional: true,
                                         type: String),
            FastlaneCore::ConfigItem.new(key: :project_reports_directory_path,
                                         env_name: "RDS_OCLINT_PROJECT_REPORTS_DIRECTORY_NAME",
                                         description: "Project reports directory path",
                                         type: String),
            FastlaneCore::ConfigItem.new(key: :general_reports_diretory_path,
                                         env_name: "RDS_OCLINT_GENERAl_REPORTS_DIRECTORY_NAME",
                                         description: "General reports directory path",
                                         optional: true,
                                         type: String),
            FastlaneCore::ConfigItem.new(key: :application_name,
                                         env_name: "RDS_OCLINT_APPLICATION_NAME",
                                         description: "Application name",
                                         type: String),
            FastlaneCore::ConfigItem.new(key: :ftp_host,
                                         env_name: "RDS_OCLINT_FTP_CLIENT_HOST",
                                         description: "FTP host",
                                         type: String),
            FastlaneCore::ConfigItem.new(key: :ftp_port,
                                         env_name: "RDS_OCLINT_FTP_CLIENT_PORT",
                                         description: "FTP port",
                                         optional: true,
                                         type: String),
            FastlaneCore::ConfigItem.new(key: :ftp_user,
                                         env_name: "RDS_OCLINT_FTP_CLIENT_USER",
                                         description: "FTP user",
                                         optional: true,
                                         type: String),
            FastlaneCore::ConfigItem.new(key: :ftp_password,
                                         env_name: "RDS_OCLINT_FTP_CLIENT_PASSWORD",
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

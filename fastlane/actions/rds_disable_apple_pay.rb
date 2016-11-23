require 'xcodeproj'

module Fastlane
  module Actions

    class RdsDisableApplePayAction < Action
      def self.run(params)
        UI.message "Starting disable Apple Pay"

        xcodeproj_path = params[:xcodeproj] || Dir["*.xcodeproj"].first
        UI.message("Xcodeproj '#{xcodeproj_path.green}' loaded")

        # validate xcodeproj path
        project_file_path = File.join(xcodeproj_path, "project.pbxproj")
        UI.user_error!("Could not find path to project config '#{project_file_path}'. Pass the path to your project (not workspace)!") unless File.exist?(project_file_path)

        target_name = params[:target_name]
        main_target = nil

        project = Xcodeproj::Project.open(xcodeproj_path)
        project.targets.each do |target|
          main_target = target if target.name == target_name
        end

        UI.user_error!("Could not find target with name '#{target_name}'.") unless main_target
        UI.message("Target with name '#{target_name.green}' find")

        # turn off Apple Pay capability
        targets_attributes = project.root_object.attributes['TargetAttributes']
        target_attributes = targets_attributes[main_target.uuid]
        system_capabilities = target_attributes['SystemCapabilities']

        UI.user_error!("In target not enabled Apple Pay.") unless system_capabilities
        system_capabilities.delete('com.apple.ApplePay')

        project.save

        entitlements_path = nil
        main_target.build_configuration_list.build_configurations.each do |build_configuration|
          entitlements_path = build_configuration.build_settings["CODE_SIGN_ENTITLEMENTS"] if build_configuration.name == 'Release'
        end
        entitlements_path ||= params[:entitlements_file]

        unless entitlements_path
          UI.success("Entitlements file not found. Apple Pay can't be disabled.")
          return
        end

        entitlements_path = File.join(xcodeproj_path, '..', entitlements_path)

        UI.message("Entitlements with path '#{entitlements_path.green}' loaded")

        entitlements = Xcodeproj::Plist.read_from_path(entitlements_path) 
        entitlements.delete('com.apple.developer.in-app-payments')

        Xcodeproj::Plist.write_to_path(entitlements, entitlements_path)
        
        # complete
        UI.success("Successfully disabled Apple Pay")
      end

      def self.description
        "This action disables Apple Pay in .xcodeproj file and in corresponding .entitlements file"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :xcodeproj,
                                       env_name: "RDS_PROJECT_PATH",
                                       description: "Path to your Xcode project",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :entitlements_file,
                                       env_name: "RDS_ENTITLEMENTS_FILE_PATH",
                                       description: "Path to your entitlements file",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :target_name,
                                       env_name: "RDS_TARGET_NAME",
                                       description: "Target name where you want to disable Apple pay")
        ]
      end

      def self.authors
        ['i.kvyatkovskiy', 'Beniamiiin']
      end

      def self.is_supported?(platform)
        [:ios].include? platform
      end
    end
  end
end

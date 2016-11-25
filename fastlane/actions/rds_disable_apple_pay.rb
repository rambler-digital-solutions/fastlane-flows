require 'xcodeproj'

module Fastlane
  module Actions

    class RdsDisableApplePayAction < Action
      def self.run(params)
        UI.message "Starting disable Apple Pay"

        xcodeproj_path = params[:xcodeproj] || Dir["*.xcodeproj"].first

        project = xcodeproject(xcodeproj_path)
        UI.message("Xcodeproj '#{xcodeproj_path.green}' loaded") if project
        UI.user_error!("Could not find project with path '#{xcodeproj_path.green}'.") unless project

        target_name = params[:target_name]
        target = target_by_name(project, target_name)
        UI.message("Target with name '#{target_name.green}' find") if target
        UI.user_error!("Could not find target with name '#{target_name.green}'.") unless target

        capabilities = system_capabilities(project, target)
        return show_not_find_entitlements_file_message unless capabilities

        # Disable Apple Pay in system capabilities
        UI.message("SystemCapabilities find")

        capabilities.delete('com.apple.ApplePay')
        project.save

        UI.message("Apple Pay disabled in System Capabilities")

        # Remove Apple Pay key from entitlements file
        entitlements_file = entitlements_path(target, params[:entitlements_file], xcodeproj_path)
        return show_not_find_entitlements_file_message unless entitlements_file
        
        entitlements = Xcodeproj::Plist.read_from_path(entitlements_file)
        return show_not_find_entitlements_file_message unless entitlements

        UI.message("Entitlements file find")
        entitlements.delete('com.apple.developer.in-app-payments')
        Xcodeproj::Plist.write_to_path(entitlements, entitlements_file)
        UI.message("Apple Pay key removed from Entitlements file")

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

      private

      def self.xcodeproject(xcodeproj_path)
        project_file_path = File.join(xcodeproj_path, "project.pbxproj")
        
        UI.user_error!("Could not find path to project config '#{project_file_path}'. Pass the path to your project (not workspace)!") unless File.exist?(project_file_path)
        
        Xcodeproj::Project.open(xcodeproj_path)
      end

      def self.target_by_name(project, target_name)
        project.targets.each do |target|
          return target if target.name == target_name
        end

        return nil
      end

      def self.system_capabilities(project, target)
        targets_attributes = project.root_object.attributes['TargetAttributes']
        target_attributes = targets_attributes[target.uuid]
        target_attributes['SystemCapabilities']
      end

      def self.entitlements_path(target, entitlements_file, xcodeproj_path)
        entitlements_path = nil
        target.build_configuration_list.build_configurations.each do |build_configuration|
          entitlements_path = build_configuration.build_settings["CODE_SIGN_ENTITLEMENTS"] if build_configuration.name == 'Release'
        end
        entitlements_file ||= entitlements_path

        File.join(xcodeproj_path, '..', entitlements_file) if entitlements_file
      end

      def self.show_not_find_entitlements_file_message
        UI.success("Entitlements file not found. Apple Pay can't be disabled.")
      end

    end
  end
end

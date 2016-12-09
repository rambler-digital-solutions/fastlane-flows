module Fastlane
  module Actions
    class UpdateAutomaticCodesigningAction < Action
      def self.run(params)
        # Обновляем настройки подписи всех таргетов проекта
        setup_signing_in_xcodeproj(params[:path], params)

        unless Dir["Pods/Pods.xcodeproj"].empty?
          # Обновляем настройки таргетов в Pods.xcodeproj
          setup_signing_in_xcodeproj(Dir["Pods/Pods.xcodeproj"].first, params)
        end

        UI.success("Successfully updated project settings to use ProvisioningStyle '#{params[:use_automatic_signing] ? 'Automatic' : 'Manual'}'")
      end

      def self.setup_signing_in_xcodeproj(xcodeproj, params)
        UI.message("Updating the Automatic Codesigning flag to #{params[:use_automatic_signing] ? 'enabled' : 'disabled'} for the given project '#{xcodeproj}'")
        project = Xcodeproj::Project.open(xcodeproj)

        targets_ids = []
        swift_versions = {}
        project.root_object.targets.each { |target|

          # Замечательный костыль - почему-то сбрасывалось поле SWIFT_VERSION у всех подов после выполнения всех скриптов, похоже на косяк Xcodeproj гема. Чтобы закостылить, сохраняем эти значения и потом их проставляем.
          swift_versions[target] = {}
          target.build_configurations.each { |config|
            swift_versions[target][config] = config.build_settings['SWIFT_VERSION']
          }
          targets_ids.push(target.uuid)
        }

        project_attrs = project.root_object.attributes
        target_attributes = project_attrs['TargetAttributes']
        if !target_attributes 
          project_attrs['TargetAttributes'] = {}
        end
        targets_ids.each { |target_id|
          if !project_attrs['TargetAttributes'][target_id]
            project_attrs['TargetAttributes'][target_id] = {}
          end
          style = params[:use_automatic_signing] ? 'Automatic' : 'Manual'
          project_attrs['TargetAttributes'][target_id]['ProvisioningStyle'] = style
        }
        project.root_object.attributes = project_attrs
        project.root_object.targets.each { |target|
          target.build_configurations.each { |config|
            config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ""
            if swift_versions[target][config]
              config.build_settings['SWIFT_VERSION'] = swift_versions[target][config]
            end
          }
        }
        project.save

      end

      def self.description
        "Updates the Xcode 8 Automatic Codesigning Flag"
      end

      def self.details
        "Updates the Xcode 8 Automatic Codesigning Flag of all targets in the project and CocoaPods"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :path,
                                       env_name: "FL_PROJECT_SIGNING_PROJECT_PATH",
                                       description: "Path to your Xcode project",
                                       verify_block: proc do |value|
                                         UI.user_error!("Path is invalid") unless File.exist?(File.expand_path(value))
                                       end),
          FastlaneCore::ConfigItem.new(key: :use_automatic_signing,
                                       env_name: "FL_PROJECT_USE_AUTOMATIC_SIGNING",
                                       description: "Defines if project should use automatic signing",
                                       default_value: false)
        ]
      end

      def self.output
      end

      def self.return_value
      end

      def self.authors
        ["mathiasAichinger"]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end

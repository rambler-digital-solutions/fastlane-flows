module Fastlane
  module Actions
    module SharedValues
      GIT_CHECKOUT_BRANCH = :GIT_CHECKOUT_BRANCH
    end

    class GitCheckoutAction < Action
      def self.run(params)
        remote_branch = params[:remote_branch]
        Actions.sh("git fetch")
        Actions.sh("git checkout #{remote_branch}")
        Actions.sh("git pull origin #{remote_branch}")
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        'Checkout a branch from project working copy'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :remote_branch,
                                       env_name: "FL_GIT_CHECKOUT_BRANCH",
                                       description: "The branch name that needs to be checkout",
                                       is_string: true,
                                       default_value: "master")
        ]
      end

      def self.output
        [
          ['GIT_CHECKOUT_BRANCH', 'The branch name that needs to be checkout']
        ]
      end

      def self.authors
        ["fabiomilano"]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end

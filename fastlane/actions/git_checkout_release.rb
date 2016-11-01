module Fastlane
  module Actions
    module SharedValues
      GIT_CHECKOUT_RELEASE_VERSION = :GIT_CHECKOUT_RELEASE_VERSION
    end

    class GitCheckoutReleaseAction < Action
      def self.run(params)
        version = params[:version]
        release_branch = "release/#{version}"
        hotfix_branch = "hotfix/#{version}"
        result_branch = ""
        
        Actions.sh("git fetch")
        branch_list = Actions.sh("git branch -a")

        
        branch_list = branch_list.split(/\n/)
	result_branch = release_branch if branch_list.any? { |branch| branch[2..-1].sub('remotes/origin/', '') == release_branch }
	result_branch = hotfix_branch if branch_list.any? { |branch| branch[2..-1].sub('remotes/origin/', '') == hotfix_branch }

        if result_branch.empty?
          result_branch = release_branch
          Actions.sh("git branch #{result_branch}")
          Actions.sh("git checkout #{result_branch}")
          Actions.sh("git push --set-upstream origin #{result_branch}")
        else
          Actions.sh("git checkout develop")
          Actions.sh("git branch -D #{result_branch}")
          Actions.sh("git checkout #{result_branch}")
          Actions.sh("git pull origin #{result_branch}")
          Helper.log.info "Successfully checkout branch #{result_branch}."
        end

        return result_branch
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        'Checkout a branch from project working copy'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :version,
                                       env_name: "FL_GIT_CHECKOUT_RELEASE_VERSION",
                                       description: "The new version",
                                       is_string: true,
                                       default_value: "1.0.0")
        ]
      end

      def self.output
        [
          ['GIT_CHECKOUT_BRANCH', 'The branch name that needs to be checkout']
        ]
      end

      def self.authors
        ["etolstoy"]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end

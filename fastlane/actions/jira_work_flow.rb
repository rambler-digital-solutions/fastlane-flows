require 'jira-ruby'

module Fastlane
  module Actions
    class JiraWorkFlowAction < Action
      
      def self.run(params)

        # Authorization
        options = {
          :username     => params[:jira_username],
          :password     => params[:jira_password],
          :site         => params[:jira_host],
          :context_path => '',
          :auth_type    => :basic
        }
        @client = DropboxClient.new(token)

        # Authorization
        params[:issue_ids].each do |issue_id|
          move_issue(issue_id, params[:jira_host])
        end

      end

      def  self.move_issue(issue_id, transition_name)

        # Find Issue
        issue = @client.Issue.find(issue_id)
        if !issue
          puts 'Issue #{issue_id} not found'
          return
        end

        # Find Transition
        transitions = @client.Transition.all(issue: issue)
        transition = transitions.find{ |elem| elem.name == transition_name }
        if !transition
          puts 'Cant move issue #{issue_id} to #{transition_name}'
          return
        end

        # Perform Transition
        new_transition = issue.transitions.build
        new_transition.save!("transition" => {"id" => transition.id})

      end

      #####################################################
      # @!group Documentation
      #####################################################
      def self.description
        'Move jira issues to ready for test'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :issue_ids,
                                       env_name: "FL_RDS_JIRA_ISSUE_IDS",
                                       description: "Path to ipa file",
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :jira_username,
                                       env_name: "FL_RDS_JIRA_USERNAME",
                                       description: "Jira username",
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :jira_password,
                                       env_name: "FL_RDS_JIRA_PASSWORD",
                                       description: "Jira password",
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :jira_host,
                                       env_name: "FL_RDS_JIRA_HOST",
                                       description: "Jira password",
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :jira_transition_name,
                                       env_name: "FL_RDS_JIRA_TRANSITION_NAME",
                                       description: "Transition name",
                                       is_string: true)
        ]
      end

      def self.authors
        ["CognitiveDisson"]
      end

      def self.is_supported?(platform)
        true
      end

    end
  end
end
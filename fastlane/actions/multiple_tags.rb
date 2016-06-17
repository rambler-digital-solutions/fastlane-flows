module Fastlane
  module Actions
    class MultipleTagsAction < Action
      def self.run(params)
        tags = params[:tags]
        tags.each do |tag|
          sh("git tag -f '#{tag}'")
          sh("git push --force origin refs/tags/#{tag}:refs/tags/#{tag}")
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        'Adds and pushes multiple git tags'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :tags,
                                       env_name: "FL_GIT_TAGS",
                                       description: "Git tags",
                                       is_string: false,
                                       default_value: [])
        ]
      end

      def self.output
        [
          ['GIT_TAGS', 'Git tags']
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
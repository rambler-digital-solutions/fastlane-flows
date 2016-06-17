module Fastlane
  module Actions
  	class GitResetAction < Action
  		
  		def self.run(params)
        	Actions.sh("git reset --hard")
        	Actions.sh("git clean -fd")
      	end

    	#####################################################
    	# @!group Documentation
    	#####################################################
        def self.description
        	'Reset a branch and clean working copy'
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
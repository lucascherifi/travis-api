require 'sidekiq'
require 'multi_json'

module Travis
  module Sidekiq
    class BuildRestart
      class ProcessingError < StandardError; end

      def perform_async(data)
        p " ==== perform async called"
        user = User.find(data['user_id'])

        ::Sidekiq::Client.push(
              'queue'   => 'build_restarts',
              'class'   => 'Travis::Hub::Sidekiq::Worker',
              'args'    => [:restart,{user: user, build_id: data['id']}]
            )
      end

    end
  end
end

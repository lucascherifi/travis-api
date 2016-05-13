require 'sidekiq/worker'
require 'multi_json'

module Travis
  module Sidekiq
    class BuildRestart
      class ProcessingError < StandardError; end

      include ::Sidekiq::Worker
      sidekiq_options queue: :build_restarts

      def perform(data)
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

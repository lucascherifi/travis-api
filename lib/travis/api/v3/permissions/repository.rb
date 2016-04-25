require 'travis/api/v3/permissions/generic'

module Travis::API::V3
  class Permissions::Repository < Permissions::Generic
    def enable?
      write?
    end

    def disable?
      write?
    end

    def star?
      write?
    end

    def unstar?
      write?
    end

    def create_request?
      write?
    end

    def create_cron?
      Travis::Features.owner_active?(:cron, object.owner) and write?
    end
  end
end

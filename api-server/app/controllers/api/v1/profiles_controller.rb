module Api
  module V1
    class ProfilesController < ApplicationController
      def show
        payload = OpenStruct.new(user: current_user)
        render_with_serializer(Api::V1::ProfileSerializer, payload)
      end
    end
  end
end

class DidsController < ApplicationController
    include ApplicationHelper
    include ActionController::MimeResponds

    # respond only to JSON requests
    respond_to :json
    respond_to :html, only: []
    respond_to :xml, only: []

    def resolve
        options = {}
        did = params[:did]
        result = resolve_did(did, options)
        if result.nil?
            render json: {"error": "not found"},
                   status: 404
            return
        end
        if result["error"] != 0
            render json: {"error": result["message"].to_s},
                   status: result["error"]
            return
        end

        render plain: w3c_did(result).to_json,
               mime_type: Mime::Type.lookup("application/ld+json"),
               content_type: 'application/ld+json',
               status: 200
    end

end
# frozen_string_literal: true

require 'multi_json'
require 'committee'
require 'hanami/api'

app = Class.new(Hanami::API) do
  get '/hello/:id' do
    json(hello: 'world', id: params.fetch(:id))
  end

  get '/hello' do
    json([{ hello: 'world' }])
  end

  post '/hello' do
    status 201
    json(hello: 'world')
  end
end.new

use Committee::Middleware::RequestValidation,
    schema_path: File.absolute_path('./openapi.yaml', __dir__),
    parse_response_by_content_type: true

use Committee::Middleware::ResponseValidation,
    schema_path: File.absolute_path('./openapi.yaml', __dir__),
    strict: true

run app

# frozen_string_literal: true

require_relative 'spec_helper'
require 'rack'
require 'openapi_first/response_validator'

RSpec.describe OpenapiFirst::ResponseValidator do
  let(:spec) { './spec/data/petstore.yaml' }

  let(:subject) do
    described_class.new(spec)
  end

  let(:request) do
    env = Rack::MockRequest.env_for('/pets')
    Rack::Request.new(env)
  end

  let(:headers) { { Rack::CONTENT_TYPE => 'application/json' } }

  describe 'valid response' do
    it 'raises nothing' do
      response_body = json_dump([
                                  { id: 42, name: 'hans' },
                                  { id: 2, name: 'Voldemort' }
                                ])
      response = Rack::MockResponse.new(200, headers, response_body)
      subject.validate(request, response)
    end

    it 'falls back to the default' do
      response_body = JSON.dump(code: 422, message: 'Not good!')
      response = Rack::MockResponse.new(422, headers, response_body)
      subject.validate(request, response)
    end

    it 'returns no errors on additional, not required properties' do
      response_body = json_dump([{ id: 42, name: 'hans', something: 'else' }])
      response = Rack::MockResponse.new(200, headers, response_body)
      subject.validate(request, response)
    end

    describe 'when operation response has has no content defined' do
      let(:spec) { './spec/data/no-response-content.yaml' }

      it 'returns no errors' do
        request = Rack::Request.new(Rack::MockRequest.env_for('/'))
        response = Rack::MockResponse.new(200, headers, 'body')
        subject.validate(request, response)
      end

      it 'returns no errors when content type is empty' do
        request = Rack::Request.new(Rack::MockRequest.env_for('/empty-content'))
        response = Rack::MockResponse.new(200, headers, 'body')
        subject.validate(request, response)
      end
    end
  end

  describe 'invalid response' do
    it 'fails on unknown http method' do
      request = begin
        env = Rack::MockRequest.env_for('/pets', method: 'PATCH')
        Rack::Request.new(env)
      end
      response_body = json_dump([{ id: 'string', name: 'hans' }])
      response = Rack::MockResponse.new(200, headers, response_body)
      expect do
        subject.validate(request, response)
      end.to raise_error OpenapiFirst::NotFoundError
    end

    it 'fails on unknown status' do
      env = Rack::MockRequest.env_for('/pets/1')
      request = Rack::Request.new(env)
      response_body = json_dump([{ id: 2, name: 'Voldemort' }])
      response = Rack::MockResponse.new(201, headers, response_body)
      expect do
        subject.validate(request, response)
      end.to raise_error OpenapiFirst::ResponseInvalid
    end

    it 'fails on wrong content type' do
      response_body = json_dump([{ id: 2, name: 'Voldemort' }])
      headers = { Rack::CONTENT_TYPE => 'application/xml' }
      response = Rack::MockResponse.new(200, headers, response_body)
      expect do
        subject.validate(request, response)
      end.to raise_error OpenapiFirst::ResponseInvalid
    end

    it 'returns errors on missing property' do
      response_body = json_dump([{ id: 42 }, { id: 2, name: 'Voldemort' }])
      response = Rack::MockResponse.new(200, headers, response_body)
      expect do
        subject.validate(request, response)
      end.to raise_error OpenapiFirst::ResponseInvalid
    end

    it 'returns errors on wrong property type' do
      response_body = json_dump([{ id: 'string', name: 'hans' }])
      response = Rack::MockResponse.new(200, headers, response_body)
      expect do
        subject.validate(request, response)
      end.to raise_error OpenapiFirst::ResponseInvalid
    end
  end
end

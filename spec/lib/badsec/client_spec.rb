# frozen_string_literal: true

require 'spec_helper'
require 'http'
require_relative '../../../lib/badsec/client'

RSpec.describe Badsec::Client do
  let(:client) { Badsec::Client.new }

  describe '#authorize' do
    context 'when the request is successful' do
      let(:response) do
        instance_double(
          HTTP::Response,
          headers: { 'Badsec-Authentication-Token' => 'something' },
          status: HTTP::Response::Status.new(200)
        )
      end

      before do
        allow_any_instance_of(HTTP::Client).to receive(:get).and_return(
          response
        )
      end

      it 'returns the response authentication token' do
        expect(client.authorize).to eq 'something'
      end
    end

    context 'when the request is not successful' do
      before do
        allow_any_instance_of(HTTP::Client).to receive(:get).and_return(
          response, response, success_response
        )
      end

      let(:response) do
        instance_double(
          HTTP::Response,
          status: HTTP::Response::Status.new(503)
        )
      end

      let(:success_response) do
        instance_double(
          HTTP::Response,
          headers: { 'Badsec-Authentication-Token' => 'something' },
          status: HTTP::Response::Status.new(200)
        )
      end

      it 'retries the request up to two times' do
        expect { client.authorize }.to output(
          /There was a problem with the request. Retrying.../
        ).to_stderr_from_any_process
      end

      it 'handles service errors by retrying' do
        allow_any_instance_of(HTTP::Client).to receive(:get).and_raise(
          HTTP::Error
        )
      rescue ExitError

        expect(client.authorize).to raise_error(Client::ExitError)

        expect { client.authorize }.to output(
          /There was a problem with the request. Retrying.../
        ).to_stderr_from_any_process
      end
    end
  end

  describe '#users_list' do
    context 'when the request is successful' do
      let(:response) do
        instance_double(
          HTTP::Response,
          headers: { 'Badsec-Authentication-Token' => 'something' },
          status: HTTP::Response::Status.new(200),
          to_s: "1234\n5678\n9101112\n13141516"
        )
      end

      before do
        allow_any_instance_of(HTTP::Client).to receive(:get).and_return(
          response
        )
      end

      it 'logs out the request body' do
        auth = client.authorize

        expect { client.users_list(auth) }.to output(
          /['1234', '5678', '9101112', '13141516']/
        ).to_stdout_from_any_process
      end
    end

    context 'when the request is not successful' do
      let(:http_client) { double(HTTP::Client, headers: http_client_stub) }
      let(:http_client_stub) { double(HTTP::Client) }
      let(:response) do
        instance_double(
          HTTP::Response,
          status: HTTP::Response::Status.new(503)
        )
      end

      let(:success_response) do
        instance_double(
          HTTP::Response,
          status: HTTP::Response::Status.new(200),
          to_s: "1234\n5678\n9101112\n13141516"
        )
      end

      it 'retries the request up to two times' do
        allow(http_client_stub).to receive(:get).and_return(
          response, response, success_response
        )

        client.instance_variable_set('@http', http_client)

        expect { client.users_list('something') }.to output(
          /There was a problem with the request. Retrying.../
        ).to_stderr_from_any_process

        expect { client.users_list('something') }.to output
          .to_stdout_from_any_process
      end

      it 'handles service errors by retrying' do
        allow(http_client_stub).to receive(:get).and_raise(HTTP::Error)
        client.instance_variable_set('@http', http_client)

      rescue ExitError
        expect { client.users_list('something') }.to output(
          /There was a problem with the request. Retrying.../
        ).to_stderr_from_any_process

        expect { client.users_list('something') }.to output
          .to_stdout_from_any_process
      end
    end
  end
end

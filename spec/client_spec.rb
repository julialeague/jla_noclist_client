require 'spec_helper'
require 'http'
require_relative '../lib/client'

RSpec.describe Client do
  describe '#authorize' do
    context 'when the request is successful' do
      let(:response) { instance_double(
        HTTP::Response,
        headers: { 'Badsec-Authentication-Token' => 'something' },
        status: HTTP::Response::Status.new(200),
        to_s: "1234\n5678\n9101112\n13141516"
      )}

      before { allow_any_instance_of(HTTP::Client).to receive(:get).and_return(response) }
      it 'returns the response authentication token' do
        client = Client.new
        expect(client.authorize).to eq 'something'
      end
    end

    context 'when the request is not successful' do
      before do
        allow_any_instance_of(HTTP::Client).to receive(:get).and_return(
          response, response, success_response
        )
      end

      let(:response) { instance_double(
        HTTP::Response,
        status: HTTP::Response::Status.new(503)
      )}
      let(:success_response) { instance_double(
        HTTP::Response,
        headers: { 'Badsec-Authentication-Token' => 'something' },
        status: HTTP::Response::Status.new(200)
      )}

      it 'retries the request up to two times' do
        client = Client.new

        expect{client.authorize}.to output(
          /There was a problem with the request. Retrying.../
        ).to_stderr_from_any_process
      end

      it 'handles service errors by retrying' do
        client = Client.new
        allow_any_instance_of(HTTP::Client).to receive(:get).and_raise(HTTP::Error)
      rescue ExitError
        expect(client.authorize).to raise_error(Client::ExitError)
        expect{client.authorize}.to output(
          /There was a problem with the request. Retrying.../
        ).to_stderr_from_any_process
      end
    end
  end

  describe '#users_list' do
    context 'when the request is successful' do
      let(:response) { instance_double(
        HTTP::Response,
        headers: { 'Badsec-Authentication-Token' => 'something' },
        status: HTTP::Response::Status.new(200),
        to_s: "1234\n5678\n9101112\n13141516"
      )}

      before { allow_any_instance_of(HTTP::Client).to receive(:get).and_return(response) }

      it 'logs out the request body' do
        client = Client.new
        auth = client.authorize
        expect{client.users_list(auth)}.to output(
          /["1234", "5678", "9101112", "13141516"]/
        ).to_stdout_from_any_process
      end
    end

    context 'when the request is not successful' do

      let(:http_client) { double(HTTP::Client, headers: http_client_stub) }
      let(:http_client_stub) { double(HTTP::Client) }
      let(:response) { instance_double(
        HTTP::Response,
        status: HTTP::Response::Status.new(503)
      )}
      let(:success_response) { instance_double(
        HTTP::Response,
        status: HTTP::Response::Status.new(200),
        to_s: "1234\n5678\n9101112\n13141516"
      )}

      it 'retries the request up to two times' do
        allow(http_client_stub).to receive(:get).and_return(response, response, success_response)
        client = Client.new
        client.instance_variable_set("@http", http_client)
        expect{client.users_list('something')}.to output(
          /There was a problem with the request. Retrying.../
        ).to_stderr_from_any_process
        expect{client.users_list('something')}.to output.to_stdout_from_any_process
      end

      it 'handles service errors by retrying' do
        allow(http_client_stub).to receive(:get).and_raise(HTTP::Error)
        client = Client.new
        client.instance_variable_set("@http", http_client)
      rescue ExitError
        expect{client.users_list('something')}.to output(
          /There was a problem with the request. Retrying.../
        ).to_stderr_from_any_process
        expect{client.users_list('something')}.to output.to_stdout_from_any_process
      end
    end
  end
end

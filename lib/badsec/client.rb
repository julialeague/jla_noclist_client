# frozen_string_literal: true

require 'http'
require 'logger'

module Badsec
  # A simple service client for the BADSEC API that is used to retrieve
  # a list of NOC users
  class Client
    MAX_RETRIES = 2
    NOCLIST_URI = 'http://0.0.0.0:8888'

    class ExitError < StandardError; end

    def initialize
      @logger = Logger.new(STDOUT)
      @error_log = Logger.new(STDERR)
      @retries = 0
      # Build an HTTP::Client with default request options
      @http = HTTP.headers('User-Agent' => 'JLA/1.0.0').accept(:text)
    end

    # Calls the BADSEC API'S authorization endpoint
    # to retrieve a valid auth token
    #
    # @return [String, nil] the auth token
    def authorize
      # Only retrieve the header for this API call,
      # the body contains nothing of use
      response = @http.head(NOCLIST_URI + '/auth')

      if response.status.success?
        @retries = 0
        response.headers['Badsec-Authentication-Token']
      else
        handle_error
        authorize
      end
    rescue HTTP::Error
      handle_error
      authorize
    end

    # Calls the BADSEC API's users list endpoint
    #
    # @param [String] auth_token The SHA256-hashed auth token for the service
    #
    # Logs the list of users to STDOUT
    #
    # @return nil
    def users_list(auth_token)
      response = @http.headers(
        'X-Request-Checksum' => auth_checksum(auth_token)
      ).get(NOCLIST_URI + '/users')

      if response.status.success?
        @logger.info(JSON.parse(response.to_s.split("\n").to_json))
        @retries = 0
      else
        handle_error
        users_list(auth_token)
      end
    rescue HTTP::Error
      handle_error
      users_list(auth_token)
    end

    private

    # Encodes a BADSEC auth token for the users list endpoint
    #
    # @param auth_token The valid BADSEC auth token
    #
    # @return hex-encoded string
    def auth_checksum(auth_token)
      auth_token ||= ''
      Digest::SHA256.hexdigest auth_token + '/users'
    end

    # Fails with [Client::ExitError] if class has reached
    # the maximum number of retries
    def exit_on_max_retry
      fail ExitError if @retries == MAX_RETRIES
    end

    # Checks whether to retry or exit, increments retry counter,
    # and logs a message to stderr
    def handle_error
      exit_on_max_retry
      @retries += 1
      @error_log.error('There was a problem with the request. Retrying...')
    end
  end
end

# This is the main program. Initializes the client class and retrieves an
# auth token from the BADSEC authorization endpoint.
# Then retrieves the users list with the valid auth token.
# Exits without the list if [Client::ExitError] is raised.
if $PROGRAM_NAME == __FILE__
  begin
    client = Badsec::Client.new
    auth_token = client.authorize
    client.users_list(auth_token)
    exit(0)
  rescue Badsec::Client::ExitError
    @error_log.error(
      'The service has failed to respond successfully. Please try again later.'
    )
    exit(1)
  end
end

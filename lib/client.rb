require 'http'
require 'logger'

class Client
  MAX_RETRIES = 2
  NOCLIST_URI = 'http://0.0.0.0:8888'.freeze

  class ExitError < StandardError; end

  def initialize
    @logger = Logger.new(STDOUT)
    @error_log = Logger.new(STDERR)
    @retries = 0
    # Build an HTTP::Client with default request options
    @http = HTTP.headers("User-Agent" => "JLA/1.0.0").accept(:text)
  end

  # Calls the BADSEC API'S authorization endpoint to retrieve a valid auth token
  #
  # @return [String, nil] the auth token
  def authorize
    response = @http.get(NOCLIST_URI + '/auth')
    if response.status.success?
      @retries = 0
      return response.headers['Badsec-Authentication-Token']
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
      "X-Request-Checksum" => auth_checksum(auth_token)
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

  # Fails with [Client::ExitError] if we have reached our maximum number of retries
  def exit_on_max_retry
    fail ExitError if @retries == MAX_RETRIES
  end

  # Checks whether we should retry or exit, and increments retry counter/logs a message to stderr
  def handle_error
    exit_on_max_retry
    @retries += 1
    @error_log.error('There was a problem with the request. Retrying...')
  end
end

# This is the main program. Initializes the client class and retrieves an auth token
# from the BADSEC authorization endpoint. Then retrieves the users list with the valid
# auth token. We will exit without the list if the [Client::ExitError] is raised.
if $0 == __FILE__
  begin
    client = Client.new
    require 'pry'
    binding.pry
    auth_token = client.authorize
    client.users_list(auth_token)
  rescue Client::ExitError
    exit(1)
  end
end

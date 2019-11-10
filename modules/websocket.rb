# frozen_string_literal: true

require 'sucker_punch'

# Handles websocket connections
class Websocket
  include SuckerPunch::Job
  @sockets = []

  # Parses websocket message
  #
  # channel - String
  # msg - String / Array / Hash
  #
  def self.parse(channel, msg)
    { channel: channel, message: msg }.to_json
  end

  # Sends the inserted message to the given ws
  #
  # websocket - Object
  # channel - String
  # msg - String / Array / Hash
  #
  def self.send_message(websocket, channel, msg)
    websocket.send(parse(channel, msg))
  end

  def perform(callback)
    send(callback[0], callback[1], callback[2])
  end

  # Sends data to clients after it having been updated
  #
  # ws - Object (Websocket)
  # user_id - Integer (User id given from session)
  #
  # Returns nothing
  #
  def update_data(websocket, user_id)
    x = DBConnector.connect.execute('SELECT * FROM current_sessions WHERE user_id = ?', user_id).first
    p x['user_id']
    unless x.nil?
      Websocket.send_message(websocket, 'weather', [Weather.get(user_id)])
      Websocket.send_message(websocket, 'traffic', PublicTransport.get(user_id))
      perform_in(5, ['update_data', websocket, user_id])
      # TODO: The above action can not be run as perform is not defined, but defined
      # requires update_data to be defined for it to run.
    end
  end

  # Makes async operation possible
  #
  # callback - Array (method to be called, method-inputs)
  #
  # Returns nothing
  #
  # rubocop:disable  Lint/DuplicateMethods
  def perform(callback)
    send(callback[0], callback[1], callback[2])
  end
  # rubocop:enable  Lint/DuplicateMethods

  # Stores the current ws sessions and initiates first data update
  #
  # ws - Object (Websocket)
  # user_id - Integer (User ID)
  #
  # Returns nothing
  #
  def self.store(websocket, user_id)
    @sockets << [websocket, user_id]
    perform_in(5, ['update_data', websocket, user_id])
  end

  # Removes a ws session from the stored sessions array
  #
  # ws - Object (Websocket)
  # user_id - Integer (User ID)
  #
  # Returns nothing
  #
  def self.remove(websocket, user_id)
    @sockets.delete([websocket, user_id])
  end
end

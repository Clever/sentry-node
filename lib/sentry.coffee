_       = require 'underscore'
os      = require 'os'
nodeurl = require 'url'
quest   = require 'quest'
util    = require 'util'
events  = require 'events'

module.exports = class Sentry extends events.EventEmitter

  # constructor must be provided a credentials string or object
  # it can also optionally be provided a settings object
  # note that if the settings object contains credentials, the credentials will be overwritten
  constructor: (credentials, settings) ->
    if _.isString credentials
      @_parseDSN credentials
    else if _.isObject credentials
      _.extend @, credentials
      if _.every(['key', 'secret', 'project_id'], (prop) -> _.has(credentials, prop))
        @enabled = true
      else
        @enabled = false
        @disable_message = "Credentials you passed in aren't complete."
    else
      @enabled = false
      @disable_message = "Sentry client expected String or Object as argument. You passed: #{credentials}."

    _.extend @, settings

    _.defaults @,
      hostname: os.hostname()
      enable_env: ['production']

  error: (err, message, logger, extra) =>
    unless err instanceof Error
      console.error 'error must be an instance of Error', err
      err = new Error 'CONVERT_TO_ERROR:' + JSON.stringify(err, null, 2)
    data =
      culprit: message # big text that appears at the top
      message: err.message # smaller text that appears right under culprit (and shows up in HipChat)
      logger: logger
      server_name: @hostname
      platform: 'node'
      level: 'error'
      extra: _(extra or {}).extend
        stacktrace: err.stack

    @_send data

  message: (message, logger, extra) =>
    data =
      message: message
      logger: logger
      level: 'info'
      extra: extra if extra?

    @_send data

  _send: (data) =>
    unless @enabled
      return console.log @disable_message

    unless process.env.NODE_ENV in @enable_env
      return console.log "If #{process.env.NODE_ENV} was enabled, would have sent to Sentry:", data

    # If you send data.logger and it's not a string, Sentry tells you that it succeeded and sends
    # you an event ID, Sentry doesn't actually do anything and the event ID that they give you
    # is nonexistent. #dealwithit
    if data.logger? and not _(data.logger).isString()
      return @emit 'error', new Error "logger must be a string, was #{JSON.stringify data.logger}"

    options =
      uri: "https://app.getsentry.com/api/#{@project_id}/store/"
      method: 'post'
      headers:
        'X-Sentry-Auth': "Sentry sentry_version=4, sentry_key=#{@key}, sentry_secret=#{@secret}, sentry_client=sentry-node"
      json: data
    quest options, (err, res, body) =>
      if err? or res.statusCode > 299
        console.error 'Error posting event to Sentry:', err, body
        @emit("error", err)
      else
        @emit("logged")

  _parseDSN: (dsn) =>
    parsed = nodeurl.parse(dsn)
    try
      @project_id = parsed.path.split('/')[1]
      [@key, @secret] = parsed.auth.split ':'
      @enabled = true
    catch err
      @enabled = false
      @disable_message = "Your SENTRY_DSN is invalid. Use correct DSN to enable your sentry client."

_       = require 'underscore'
os      = require 'os'
nodeurl = require 'url'
quest   = require 'quest'
util    = require 'util'
events  = require 'events'

module.exports = class Sentry extends events.EventEmitter

  constructor: (settings) ->
    # first check if sentry dsn is set as environment variable
    @_parseDSN(process.env.SENTRY_DSN or "")
    
    # credentials are updated if explicitly passed in
    if settings?
      if _(settings).isString()
        @_parseDSN settings
      else if _(settings).isObject()
        _(@).extend settings
        if _.every(['key', 'secret', 'project_id'], (prop) -> _.has(settings, prop))
          @enabled = true
        else
          @enabled = false
          @disable_message = "Credentials you passed in aren't complete."
      else
        @enabled = false
        @disable_message = "Sentry client expected String or Object as argument. You passed: #{settings}."
      
    _(@).defaults
      hostname: os.hostname()
      enable_env: ['production']
    return
    
  error: (err, message, logger, extra) =>
    throw new Error 'error must be an instance of Error' unless err instanceof Error
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
     
  _parseDSN: (dsn) =>
    if dsn
      parsed = nodeurl.parse(dsn)
      try
        @project_id = parsed.path.split('/')[1]
        [@key, @secret] = parsed.auth.split ':'
        @enabled = true
      catch err
        @enabled = false
        @disable_message = "Your SENTRY_DSN is invalid. Use correct DSN to enable your sentry client."
    else
      @enabled = false
      @disable_message = "You SENTRY_DSN is missing or empty. Sentry client is disabled."

  _send: (data) =>
    unless @enabled
      return console.log @disable_message
      
    unless process.env.NODE_ENV in @enable_env
      return console.log "If #{process.env.NODE_ENV} was enabled, would have sent to Sentry:", data

    options =
      uri: "https://app.getsentry.com/api/#{@project_id}/store/"
      method: 'post'
      headers:
        'X-Sentry-Auth': "Sentry sentry_version=4, sentry_key=#{@key}, sentry_secret=#{@secret}, sentry_client=sentry-node/0.1.3"
      json: data
    quest options, (err, res, body) =>
      if err? or res.statusCode > 299
        console.error 'Error posting event to Sentry:', err, body
        @emit("error", err)
      else
        @emit("logged")

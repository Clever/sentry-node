_       = require 'underscore'
os      = require 'os'
nodeurl = require 'url'
quest   = require 'quest'

module.exports = class Sentry

  constructor: (settings) ->
    parsed = false
    
    if settings?
      if typeof(settings) is 'string'
        @_parseDSN settings
        parsed = true
      else if _.every(['key', 'secret', 'project_id'], (prop) -> _.has(settings, prop))
        _(@).defaults settings
        parsed = true
    else if process.env.SENTRY_DSN?
      @_parseDSN process.env.SENTRY_DSN
      parsed = true
      
    if parsed
      @hostname = os.hostname()
      @enable_env = ['production']
    else
      throw new Error 'Sentry Authentications are required to use the HTTP API.'
    return
    
  error: (err, message, logger, extra) =>
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
    parsed = nodeurl.parse(dsn)
    @project_id = parsed.path.split('/')[1]
    [@key, @secret] = parsed.auth.split ':'

  _send: (data) =>
    unless process.env.NODE_ENV in @enable_env
      return console.log "If #{process.env.NODE_ENV} was enabled, would have sent to Sentry:", data

    options =
      uri: "https://app.getsentry.com/api/#{@project_id}/store/"
      method: 'post'
      headers:
        'X-Sentry-Auth': "Sentry sentry_version=4, sentry_key=#{@key}, sentry_secret=#{@secret}, sentry_client=sentry-node/0.1.0"
      json: data
    quest options, (err, res, body) ->
      if err? or res.statusCode > 299
        console.error 'Error posting event to Sentry:', err, body

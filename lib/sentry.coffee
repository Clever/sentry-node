_       = require 'underscore'
os      = require 'os'
nodeurl = require 'url'
quest   = require 'quest'
util    = require 'util'
events  = require 'events'

parseDSN = (dsn) ->
  try
    {auth, pathname} = nodeurl.parse dsn
    [key, secret] = auth.split ':'
    project_id = pathname.split('/')[1]
    {key, secret, project_id}
  catch err
    {}

module.exports = class Sentry extends events.EventEmitter

  constructor: (credentials) ->
    @enabled = false
    credentials = parseDSN credentials if _.isString credentials
    if not _.isObject credentials
      @disable_message = "Sentry client expected String or Object as argument. You passed: #{credentials}."
    else if _.every(['key', 'secret', 'project_id'], (prop) -> _.has(credentials, prop))
      _.extend @, credentials
      @enabled = true
    else
      @disable_message = "Credentials you passed in aren't complete."

    _.defaults @, hostname: os.hostname()

  error: (err, logger, culprit, extra = {}) =>
    unless err instanceof Error
      err = new Error "WARNING: err not passed as Error! #{JSON.stringify(err, null, 2)}"
      @emit 'warning', new Error err
    data =
      message: err.message # smaller text that appears right under culprit (and shows up in HipChat)
      logger: logger
      server_name: @hostname
      platform: 'node'
      level: 'error'
      extra: util.inspect _.extend(extra, {stacktrace: err.stack}), {depth: null}
    _.extend data, culprit: culprit if not _.isNull culprit
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

    # data.logger must be a string else sentry fails quietly
    if data.logger? and not _.isString data.logger
      data.logger = "WARNING: logger not passed as string! #{JSON.stringify(data.logger)}"
      @emit 'warning', new Error data.logger

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

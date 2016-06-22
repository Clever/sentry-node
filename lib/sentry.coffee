_       = require 'underscore'
os      = require 'os'
nodeurl = require 'url'
quest   = require 'quest'
util    = require 'util'
events  = require 'events'
scrub   = require('loofah').default()

parseDSN = (dsn) ->
  try
    {auth, pathname} = nodeurl.parse dsn
    [key, secret] = auth.split ':'
    project_id = pathname.split('/')[1]
    {key, secret, project_id}
  catch err
    {}

_handle_http_load_errors = (context, err) ->
  context.emit "warning", err

# Takes an amount of time (in milliseconds) and a function and produces a function that calls the
# given function with a timeout. If the given function doesn't call its callback within the
# specified amount of time, the callback will be called with an error.
with_timeout = (msecs, fn) -> (args..., cb) ->
  cb = _.once cb
  setTimeout (-> cb new Error 'Sentry timed out'), msecs
  fn args..., (results...) -> cb results...

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

  error: (err, logger, culprit, extra = {}, cb) =>
    unless err instanceof Error
      err = new Error "WARNING: err not passed as Error! #{JSON.stringify(err, null, 2)}"
      @emit 'warning', err

    data =
      message: err.message # smaller text that appears right under culprit (and shows up in HipChat)
      logger: logger
      server_name: @hostname
      platform: 'node'
      level: 'error'
      extra: _.extend extra, {stacktrace: err.stack}
    _.extend data, culprit: culprit if not _.isNull culprit
    @_send data, cb

  message: (message, logger, extra={}, cb) =>
    data =
      message: message
      logger: logger
      level: 'info'
      extra: extra
    @_send data, cb

  _send: (data, cb) =>
    unless cb?
      cb = ->

    unless @enabled
      @emit("done")
      console.log @disable_message
      return setImmediate cb

    # data.logger must be a string else sentry fails quietly
    if data.logger? and not _.isString data.logger
      data.logger = "WARNING: logger not passed as string! #{JSON.stringify(data.logger)}"
      @emit 'warning', new Error data.logger

    try JSON.stringify(data.extra) catch
      @emit 'warning', new Error "WARNING: extra not parseable to JSON!"
      data.extra = serialized: util.inspect data.extra, {depth: null}

    options =
      uri: "https://app.getsentry.com/api/#{@project_id}/store/"
      method: 'post'
      headers:
        'X-Sentry-Auth': "Sentry sentry_version=4, sentry_key=#{@key}, sentry_secret=#{@secret}, sentry_client=sentry-node"
      json: data
    quest options, (err, res, body) =>
      @emit("done")
      if err? or res.statusCode > 299
        if res.statusCode in [429, 413]
          _handle_http_load_errors @, err
          return cb(err or new Error("status code: #{res.statusCode}"))
        console.error 'Error posting event to Sentry:', err, body
        @emit("error", err)
        return cb(err or new Error("status code: #{res.statusCode}"))
      else
        @emit("logged")
        return cb()

  wrapper: (logger, timeout = 5000) =>

    log_to_sentry = with_timeout timeout, (err, extra, cb) =>
      @once 'logged', -> cb()
      @once 'error', (sentry_err) -> cb sentry_err
      @error scrub(err), logger, null, scrub(extra)

    # Takes a function and produces a function that calls the given function, sending any errors it
    # produces to Sentry.
    globals: {}
    wrap:
      if @enabled
        (fn) -> (args..., cb) =>
          ret = fn args..., (err, results...) =>
            if err?
              extra = this.globals
              extra.args = args
              log_to_sentry err, extra, (sentry_err) ->
                cb if sentry_err? then _.extend sentry_err, original_error: err else err
            else
              cb null, results...
          if ret && ret.then and ret.catch
            ret.then (val) =>
              cb null, val
            .catch (err) =>
              log_to_sentry err, {args}, (sentry_err) ->
                cb if sentry_err? then _.extend sentry_err, original_error: err else err
      else
        (fn) -> fn

module.exports._private = {_handle_http_load_errors} if process.env.NODE_ENV is 'test'

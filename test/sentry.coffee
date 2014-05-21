_ = require 'underscore'
assert = require 'assert'
os = require 'os'
nock = require 'nock'

Sentry = require("#{__dirname}/../lib/sentry")
sentry_settings = require("#{__dirname}/credentials").sentry


describe 'sentry-node', ->

  before ->
    @sentry = new Sentry sentry_settings
    # because only in production env sentry api would make http request
    process.env.NODE_ENV = 'production'

  # mock sentry dsn with random uuid as public_key and secret_key
  dsn = 'https://123456789abcdefb:fedcba09876543214@app.getsentry.com/13578'
  dsn2 = 'https://123456789abcdefc:fedcba09876543215@app.getsentry.com/13579'

  it 'setup sentry client from SENTRY_DSN correctly', ->

    process.env.SENTRY_DSN = dsn
    _sentry = new Sentry()
    assert.equal _sentry.key, '123456789abcdefb'
    assert.equal _sentry.secret, 'fedcba09876543214'
    assert.equal _sentry.project_id, '13578'
    assert.equal os.hostname(), _sentry.hostname
    assert.deepEqual ['production'], _sentry.enable_env
    assert.equal _sentry.enabled, true

  it 'prefers the specified dsn to the environmental SENTRY_DSN', ->
    _sentry = new Sentry dsn2
    assert.equal _sentry.key, '123456789abcdefc'
    assert.equal _sentry.secret, 'fedcba09876543215'
    assert.equal _sentry.project_id, '13579'
    assert.equal os.hostname(), _sentry.hostname
    assert.deepEqual ['production'], _sentry.enable_env
    assert.equal _sentry.enabled, true

  it 'sets up sentry client from specified DSN correctly', ->
    delete process.env.SENTRY_DSN
    _sentry = new Sentry dsn
    assert.equal _sentry.key, '123456789abcdefb'
    assert.equal _sentry.secret, 'fedcba09876543214'
    assert.equal _sentry.project_id, '13578'
    assert.equal os.hostname(), _sentry.hostname
    assert.deepEqual ['production'], _sentry.enable_env
    assert.equal _sentry.enabled, true

  it 'setup sentry client from credentials correctly', ->
    assert.equal sentry_settings.key, @sentry.key
    assert.equal sentry_settings.secret, @sentry.secret
    assert.equal sentry_settings.project_id, @sentry.project_id
    assert.equal os.hostname(), @sentry.hostname
    assert.deepEqual ['production'], @sentry.enable_env
    assert.equal @sentry.enabled, true

  it 'setup sentry client settings from settings passed in correctly', ->
    _sentry = new Sentry { enable_env: ['production', 'staging'] }
    assert.deepEqual _sentry.enable_env, ['production', 'staging']

  it 'empty or missing DSN should disable the client', ->
    _sentry = new Sentry ""
    assert.equal _sentry.enabled, false
    assert.equal _sentry.disable_message, "Your SENTRY_DSN is invalid. Use correct DSN to enable your sentry client."

    _sentry = new Sentry()
    assert.equal _sentry.enabled, false
    assert.equal _sentry.disable_message, "Your SENTRY_DSN is missing or empty. Sentry client is disabled."

  it 'invalid DSN should disable the client', ->
    _sentry = new Sentry "https://app.getsentry.com/13578"
    assert.equal _sentry.enabled, false
    assert.equal _sentry.disable_message, "Your SENTRY_DSN is invalid. Use correct DSN to enable your sentry client."

  it 'passed in settings should update credentials of sentry client', ->
    dsn = 'https://123456789abcdefb:fedcba09876543214@app.getsentry.com/13578'
    process.env.SENTRY_DSN = dsn
    _sentry = new Sentry(sentry_settings)
    assert.equal sentry_settings.key, _sentry.key
    assert.equal sentry_settings.secret, _sentry.secret
    assert.equal sentry_settings.project_id, _sentry.project_id

  it 'warns if passed an error that isnt an instance of Error', ->
    scope = nock('https://app.getsentry.com')
      .matchHeader('X-Sentry-Auth'
      , "Sentry sentry_version=4, sentry_key=#{sentry_settings.key}, sentry_secret=#{sentry_settings.secret}, sentry_client=sentry-node")
      .filteringRequestBody (path) ->
        params = JSON.parse path
        if _.every(['culprit','message','logger','server_name','platform','level'], (prop) -> _.has(params, prop))
          if params.extra?.stacktrace? and params.message.indexOf('CONVERT_TO_ERROR:') != -1
            return 'error'
        throw Error 'Body of Sentry error request is incorrect.'
      .post("/api/#{sentry_settings.project_id}/store/", 'error')
      .reply(200, {"id": "534f9b1b491241b28ee8d6b571e1999d"}) # mock sentry response with a random uuid

    @sentry.error 'not an Error', 'message', 'path/to/logger'
    scope.done()

  it 'send error correctly', ->
    scope = nock('https://app.getsentry.com')
      .matchHeader('X-Sentry-Auth'
      , "Sentry sentry_version=4, sentry_key=#{sentry_settings.key}, sentry_secret=#{sentry_settings.secret}, sentry_client=sentry-node")
      .filteringRequestBody (path) ->
        params = JSON.parse path
        if _.every(['culprit','message','logger','server_name','platform','level'], (prop) -> _.has(params, prop))
          if params.extra?.stacktrace?
            return 'error'
        throw Error 'Body of Sentry error request is incorrect.'
      .post("/api/#{sentry_settings.project_id}/store/", 'error')
      .reply(200, {"id": "534f9b1b491241b28ee8d6b571e1999d"}) # mock sentry response with a random uuid

    @sentry.error new Error('Error message'), 'message', '/path/to/logger'
    scope.done()

  it 'send message correctly', ->
    scope = nock('https://app.getsentry.com')
      .matchHeader('X-Sentry-Auth'
      , "Sentry sentry_version=4, sentry_key=#{sentry_settings.key}, sentry_secret=#{sentry_settings.secret}, sentry_client=sentry-node")
      .filteringRequestBody (path) ->
        params = JSON.parse path
        if _.every(['message','logger','level'], (prop) -> _.has(params, prop))
          unless _.some(['culprit','server_name','platform','extra'], (prop) -> _.has(params, prop))
            return 'message'
        throw Error 'Body of Sentry message request is incorrect.'
      .post("/api/#{sentry_settings.project_id}/store/", 'message')
      .reply(200, {"id": "c3115249083246efa839cfac2abbdefb"}) # mock sentry response with a random uuid

    @sentry.message 'message', '/path/to/logger'
    scope.done()

  it 'emit logged event when successfully made an api call', (done) ->
    scope = nock('https://app.getsentry.com')
      .filteringRequestBody(/.*/, '*')
      .post("/api/#{sentry_settings.project_id}/store/", '*')
      .reply(200, 'OK')

    @sentry.on 'logged', ->
      scope.done()
      done()

    @sentry.error new Error('wtf?'), "Unknown Error", "/"

  it 'emit error event when the api call returned an error', (done) ->
    scope = nock('https://app.getsentry.com')
      .filteringRequestBody(/.*/, '*')
      .post("/api/#{sentry_settings.project_id}/store/", '*')
      .reply(500, 'Oops!', {'x-sentry-error': 'Oops!'})

    @sentry.once 'error', (err) ->
      scope.done()
      done()

    @sentry.message "hey!", "/"

  it 'one time listener should work correctly', (done) ->
    _sentry = new Sentry(sentry_settings)

    scope = nock('https://app.getsentry.com')
      .filteringRequestBody(/.*/, '*')
      .post("/api/#{sentry_settings.project_id}/store/", '*')
      .reply(500, 'Oops!', {'x-sentry-error': 'Oops!'})

    _sentry.once 'error', ->
      scope.done()
      done()

    _sentry.message "hey!", "/"

  it 'converts the logger to a string if you pass it a non string logger', (done) ->
    logger = key: '/path/to/logger'
    @sentry.once 'note', (err) ->
      assert.equal err.message, "#{JSON.stringify logger}\nNB: logger was converted to a string."
      done()
    @sentry.error new Error('Error message'), 'message', logger

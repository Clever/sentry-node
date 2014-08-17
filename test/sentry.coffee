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
  dsn = 'https://1234567890abcdef:fedcba0987654321@app.getsentry.com/12345'

  beforeEach -> @scope = null
  afterEach -> @scope?.done()

  it 'setup sentry client from specified DSN correctly', ->
    _sentry = new Sentry dsn
    assert.equal _sentry.key, '1234567890abcdef'
    assert.equal _sentry.secret, 'fedcba0987654321'
    assert.equal _sentry.project_id, '12345'
    assert.equal os.hostname(), _sentry.hostname
    assert.equal _sentry.enabled, true

  it 'setup sentry client from object correctly', ->
    assert.equal @sentry.key, sentry_settings.key
    assert.equal @sentry.secret, sentry_settings.secret
    assert.equal @sentry.project_id, sentry_settings.project_id
    assert.equal @sentry.hostname, os.hostname()
    assert.equal @sentry.enabled, true

  it 'refuses to enable the sentry with incomplete credentials', ->
    _sentry = new Sentry _.omit sentry_settings, 'secret'
    assert.equal _sentry.hostname, os.hostname()
    assert.equal _sentry.enabled, false
    assert.equal _sentry.disable_message, "Credentials you passed in aren't complete."

  it 'empty or missing DSN should disable the client', ->
    _sentry = new Sentry ""
    assert.equal _sentry.enabled, false
    assert.equal _sentry.disable_message, "Credentials you passed in aren't complete."

    _sentry = new Sentry()
    assert.equal _sentry.enabled, false
    assert.equal _sentry.disable_message, "Sentry client expected String or Object as argument. You passed: undefined."

  it 'invalid DSN should disable the client', ->
    _sentry = new Sentry "https://app.getsentry.com/12345"
    assert.equal _sentry.enabled, false
    assert.equal _sentry.disable_message, "Credentials you passed in aren't complete."

  it 'warns if passed an error that isnt an instance of Error', ->
    @scope = nock('https://app.getsentry.com')
      .matchHeader('X-Sentry-Auth'
      , "Sentry sentry_version=4, sentry_key=#{sentry_settings.key}, sentry_secret=#{sentry_settings.secret}, sentry_client=sentry-node")
      .filteringRequestBody (path) ->
        params = JSON.parse path
        if _.every(['culprit','message','logger','server_name','platform','level'], (prop) -> _.has(params, prop))
          if params.message.indexOf('WARNING: err') != -1
            return 'error'
        throw Error 'Body of Sentry error request is incorrect.'
      .post("/api/#{sentry_settings.project_id}/store/", 'error')
      .reply(200, {"id": "534f9b1b491241b28ee8d6b571e1999d"}) # mock sentry response with a random uuid

    @sentry.error 'not an Error', 'path/to/logger', 'culprit'

  it 'send error correctly', ->
    @scope = nock('https://app.getsentry.com')
      .matchHeader('X-Sentry-Auth'
      , "Sentry sentry_version=4, sentry_key=#{sentry_settings.key}, sentry_secret=#{sentry_settings.secret}, sentry_client=sentry-node")
      .filteringRequestBody (path) ->
        params = JSON.parse path
        if _.every(['culprit','message','logger','server_name','platform','level'], (prop) -> _.has(params, prop))
          return 'error'
        throw Error 'Body of Sentry error request is incorrect.'
      .post("/api/#{sentry_settings.project_id}/store/", 'error')
      .reply(200, {"id": "534f9b1b491241b28ee8d6b571e1999d"}) # mock sentry response with a random uuid

    @sentry.error new Error('Error message'), '/path/to/logger', 'culprit'

  it 'send error correctly when culprit not defined', ->
    @scope = nock('https://app.getsentry.com')
      .matchHeader('X-Sentry-Auth'
      , "Sentry sentry_version=4, sentry_key=#{sentry_settings.key}, sentry_secret=#{sentry_settings.secret}, sentry_client=sentry-node")
      .filteringRequestBody (path) ->
        params = JSON.parse path
        if _.every(['message','logger','server_name','platform','level'], (prop) -> _.has(params, prop))
          return 'error'
        throw Error 'Body of Sentry error request is incorrect.'
      .post("/api/#{sentry_settings.project_id}/store/", 'error')
      .reply(200, {"id": "534f9b1b491241b28ee8d6b571e1999d"}) # mock sentry response with a random uuid

    @sentry.error new Error('Error message'), '/path/to/logger', null

  it 'send error correctly if there are circular references in "extra"', (done) ->
    @scope = nock('https://app.getsentry.com')
      .matchHeader('X-Sentry-Auth'
      , "Sentry sentry_version=4, sentry_key=#{sentry_settings.key}, sentry_secret=#{sentry_settings.secret}, sentry_client=sentry-node")
      .filteringRequestBody (path) ->
        params = JSON.parse path
        if _.every(['culprit','message','logger','server_name','platform','level','extra'], (prop) -> _.has(params, prop))
          return 'error'
        throw Error 'Body of Sentry error request is incorrect.'
      .post("/api/#{sentry_settings.project_id}/store/", 'error')
      .reply(200, {"id": "534f9b1b491241b28ee8d6b571e1999d"}) # mock sentry response with a random uuid

    extra = {foo: 'bar'}
    extra = _.extend extra, {circular: extra}

    @sentry.once 'warning', (err) ->
      assert.equal err.message, "WARNING: extra not parseable to JSON!"
      done()

    @sentry.error new Error('Error message'), '/path/to/logger', 'culprit', extra

  it 'send message correctly', ->
    @scope = nock('https://app.getsentry.com')
      .matchHeader('X-Sentry-Auth'
      , "Sentry sentry_version=4, sentry_key=#{sentry_settings.key}, sentry_secret=#{sentry_settings.secret}, sentry_client=sentry-node")
      .filteringRequestBody (path) ->
        params = JSON.parse path
        if _.every(['message','logger','level'], (prop) -> _.has(params, prop))
          unless _.some(['culprit','server_name','platform'], (prop) -> _.has(params, prop))
            return 'message'
        throw Error 'Body of Sentry message request is incorrect.'
      .post("/api/#{sentry_settings.project_id}/store/", 'message')
      .reply(200, {"id": "c3115249083246efa839cfac2abbdefb"}) # mock sentry response with a random uuid

    @sentry.message 'message', '/path/to/logger'

  it 'emit logged event when successfully made an api call', (done) ->
    @scope = nock('https://app.getsentry.com')
      .filteringRequestBody(/.*/, '*')
      .post("/api/#{sentry_settings.project_id}/store/", '*')
      .reply(200, 'OK')

    @sentry.on 'logged', -> done()

    @sentry.error new Error('wtf?'), "Unknown Error", "/"

  it 'emit error event when the api call returned an error', (done) ->
    @scope = nock('https://app.getsentry.com')
      .filteringRequestBody(/.*/, '*')
      .post("/api/#{sentry_settings.project_id}/store/", '*')
      .reply(500, 'Oops!', {'x-sentry-error': 'Oops!'})

    @sentry.once 'error', (err) -> done()

    @sentry.message "hey!", "/"

  it 'one time listener should work correctly', (done) ->
    _sentry = new Sentry(sentry_settings)

    @scope = nock('https://app.getsentry.com')
      .filteringRequestBody(/.*/, '*')
      .post("/api/#{sentry_settings.project_id}/store/", '*')
      .reply(500, 'Oops!', {'x-sentry-error': 'Oops!'})

    _sentry.once 'error', -> done()

    _sentry.message "hey!", "/"

  it 'converts the logger to a string if you pass it a non string logger', (done) ->
    logger = key: '/path/to/logger'
    @sentry.once 'warning', (err) ->
      assert.equal err.message, "WARNING: logger not passed as string! #{JSON.stringify(logger)}"
      done()
    @sentry.error new Error('Error message'), logger, "some culprit"

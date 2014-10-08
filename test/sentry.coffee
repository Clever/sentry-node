_ = require 'underscore'
assert = require 'assert'
os = require 'os'
nock = require 'nock'
sinon = require 'sinon'

Sentry = require("#{__dirname}/../lib/sentry")
sentry_settings = require("#{__dirname}/credentials").sentry


describe 'Sentry', ->

  beforeEach ->
    @sentry = new Sentry sentry_settings
    # because only in production env sentry api would make http request
    process.env.NODE_ENV = 'production'

  describe 'constructor', ->
    it 'setup sentry client from specified DSN correctly', ->
      key = '1234567890abcdef'
      secret = 'fedcba0987654321'
      project_id = '12345'
      # mock sentry dsn with random uuid as public_key and secret_key
      dsn = "https://#{key}:#{secret}@app.getsentry.com/#{project_id}"
      _sentry = new Sentry dsn
      assert.equal _sentry.key, key
      assert.equal _sentry.secret, secret
      assert.equal _sentry.project_id, project_id
      assert.equal _sentry.hostname, os.hostname()
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

  describe '#error', ->
    beforeEach ->
      sinon.stub @sentry, '_send'

    it 'emits warning if passed an error that isnt an instance of Error', (done) ->
      @sentry.on 'warning', (err) ->
        assert err instanceof Error
        assert err.message.match /^WARNING: err not passed as Error!/
        done()

      @sentry.error 'not an Error', 'path/to/logger', 'culprit'

    it 'uses _send to send error', ->
      [err_message, logger, culprit] = ['Error message', '/path/to/logger', 'culprit']

      @sentry.error new Error(err_message), logger, culprit
      assert @sentry._send.calledOnce

      send_data = @sentry._send.getCall(0).args[0]
      assert err_message == send_data.message, "Unexpected message. Expected '#{err_message}', Received '#{send_data.message}'"
      assert logger == send_data.logger, "Unexpected logger. Expected '#{logger}', Received '#{send_data.logger}'"
      assert !_.isUndefined send_data.server_name, "Expected a value to be set for server_name, undefined given"
      assert culprit == send_data.culprit, "Unexpected culprit. Expected '#{culprit}', Received '#{send_data.culprit}'"
      assert 'node' == send_data.platform, "Unexpected platform. Expected 'node', Received '#{send_data.platform}'"
      assert 'error' == send_data.level, "Unexpected level. Expected 'error', Received '#{send_data.level}'"

    it 'will send error correctly when culprit is null', ->
      @sentry.error new Error('Error message'), '/path/to/logger', null
      send_data = @sentry._send.getCall(0).args[0]
      
      assert _.isUndefined(send_data.culprit)

  describe '#message', ->
    beforeEach ->
      sinon.stub @sentry, '_send'

    it 'send message correctly via _send', ->
      @sentry.message 'message', '/path/to/logger'

      assert @sentry._send.calledOnce

      send_data = @sentry._send.getCall(0).args[0]
      assert 'message' == send_data.message, "Unexpected message. Expected 'message', Received '#{send_data.message}'"
      assert '/path/to/logger' == send_data.logger, "Unexpected logger. Expected '/path/to/logger', Received '#{send_data.logger}'"
      assert 'info' == send_data.level, "Unexpected level. Expected 'info', Received '#{send_data.level}'"

  describe '#_handle_http_429', ->
    it 'should have a function to handle http 429', ->
      assert _.isFunction @sentry._handle_http_429, 'Expected Sentry to have fn _handle_http_429'

  describe '#_send', ->
    beforeEach ->
      sinon.spy @sentry, '_handle_http_429'

    it 'emit error event when the api call returned an error', (done) ->
      scope = nock('https://app.getsentry.com')
        .filteringRequestBody(/.*/, '*')
        .post("/api/#{sentry_settings.project_id}/store/", '*')
        .reply(500, 'Oops!', {'x-sentry-error': 'Oops!'})

      @sentry.once 'error', (err) -> 
        scope.done()
        done()

      @sentry.message "hey!", "/"

    it 'emits logged event when successfully made an api call', (done) ->
      @scope = nock('https://app.getsentry.com')
        .filteringRequestBody(/.*/, '*')
        .post("/api/#{sentry_settings.project_id}/store/", '*')
        .reply(200, 'OK')

      @sentry.on 'logged', -> 
      done()

      @sentry._send get_mock_data()

    it 'converts the logger to a string if you pass it a non string logger', (done) ->
      scope = nock('https://app.getsentry.com')
        .filteringRequestBody(/.*/, '*')
        .post("/api/#{sentry_settings.project_id}/store/", '*')
        .reply(200, 'OK')

      logger = key: '/path/to/logger'
      @sentry.once 'warning', (err) ->
        assert.equal err.message, "WARNING: logger not passed as string! #{JSON.stringify(logger)}"

      @sentry.once 'logged', ->
        scope.done()
        done()

      data = get_mock_data()
      data.logger = logger

      @sentry._send data

    it 'should call _handle_http_429 on a HTTP 429', (done) ->
      scope = nock('https://app.getsentry.com')
        .post("/api/#{sentry_settings.project_id}/store/")
        .reply(429, 'Too Many Requests', {'x-sentry-error': 'Too Many Requests'})

      sentry_ref = @sentry
      @sentry.on 'warning', ->
        assert sentry_ref._handle_http_429.calledOnce
        scope.done()
        done()

      @sentry._send get_mock_data

    it 'sends error correctly if there are circular references in "extra"', (done) ->
      scope = nock('https://app.getsentry.com')
        .filteringRequestBody(/.*/, '*')
        .post("/api/#{sentry_settings.project_id}/store/", '*')
        .reply(200, 'OK')

      extra = {foo: 'bar'}
      extra = _.extend extra, {circular: extra}

      # we have to wait for both to finish
      warning_called = false
      logged_called = false

      @sentry.once 'warning', (err) ->
        warning_called = true
        assert.equal err.message, "WARNING: extra not parseable to JSON!"
        scope.done() if logged_called
        done() if logged_called

      @sentry.once 'logged', ->
        logged_called = true
        scope.done() if warning_called
        done() if warning_called

      @sentry.error new Error('Error message'), '/path/to/logger', 'culprit', extra


  describe '#_handle_http_429', ->
    it 'should emit a warning when invoked', (done) ->
      my_error = new Error 'Testing 429'
      @sentry.once 'warning', (err) ->
        assert err == my_error
        done()

      @sentry._handle_http_429 my_error

  get_mock_data = ->
    err = new Error 'Testing sentry'

    message: err.message # smaller text that appears right under culprit (and shows up in HipChat)
    logger: '/path/to/logger'
    server_name: 'apple'
    platform: 'node'
    level: 'error'
    extra: err.stack
    culprit: 'Too many tests... jk'

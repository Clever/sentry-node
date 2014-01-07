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
    
  it 'setup sentry client from SENTRY_DSN correctly', (done) ->
    # mock sentry dsn with random uuid as public_key and secret_key
    dsn = 'https://c28500314a0f4cf28b6d658c3dd37ddb:a5d3fcd72b70494b877a1c2deba6ad74@app.getsentry.com/16088'
    
    process.env.SENTRY_DSN = dsn
    _sentry = new Sentry()
    assert.equal _sentry.key, 'c28500314a0f4cf28b6d658c3dd37ddb'
    assert.equal _sentry.secret, 'a5d3fcd72b70494b877a1c2deba6ad74'
    assert.equal _sentry.project_id, '16088'
    assert.equal os.hostname(), _sentry.hostname
    assert.deepEqual ['production'], _sentry.enable_env
    assert.equal _sentry.enabled, true
    
    delete process.env.SENTRY_DSN
    _sentry = new Sentry dsn
    assert.equal _sentry.key, 'c28500314a0f4cf28b6d658c3dd37ddb'
    assert.equal _sentry.secret, 'a5d3fcd72b70494b877a1c2deba6ad74'
    assert.equal _sentry.project_id, '16088'
    assert.equal os.hostname(), _sentry.hostname
    assert.deepEqual ['production'], _sentry.enable_env
    assert.equal _sentry.enabled, true
    
    done()
    
  it 'setup sentry client from credentials correctly', (done) ->
    assert.equal sentry_settings.key, @sentry.key
    assert.equal sentry_settings.secret, @sentry.secret
    assert.equal sentry_settings.project_id, @sentry.project_id
    assert.equal os.hostname(), @sentry.hostname
    assert.deepEqual ['production'], @sentry.enable_env
    assert.equal @sentry.enabled, true
    done()
    
  it 'setup sentry client settings from settings passed in correctly', (done) ->
    _sentry = new Sentry { enable_env: ['production', 'staging'] }
    assert.deepEqual _sentry.enable_env, ['production', 'staging']
    done()
    
  it 'empty or missing DSN should disable the client', (done) ->
    _sentry = new Sentry ""
    assert.equal _sentry.enabled, false
    assert.equal _sentry.disable_message, "You SENTRY_DSN is missing or empty. Sentry client is disabled."
    
    _sentry = new Sentry()
    assert.equal _sentry.enabled, false
    assert.equal _sentry.disable_message, "You SENTRY_DSN is missing or empty. Sentry client is disabled."
    done()
    
  it 'invalid DSN should disable the client', (done) ->
    _sentry = new Sentry "https://app.getsentry.com/16088"
    assert.equal _sentry.enabled, false
    assert.equal _sentry.disable_message, "Your SENTRY_DSN is invalid. Use correct DSN to enable your sentry client."
    done()
    
  it 'passed in settings should update credentials of sentry client', (done) ->
    dsn = 'https://c28500314a0f4cf28b6d658c3dd37ddb:a5d3fcd72b70494b877a1c2deba6ad74@app.getsentry.com/16088'
    process.env.SENTRY_DSN = dsn
    _sentry = new Sentry(sentry_settings)
    assert.equal sentry_settings.key, _sentry.key
    assert.equal sentry_settings.secret, _sentry.secret
    assert.equal sentry_settings.project_id, _sentry.project_id
    done()
    
  it 'fails if passed an error that isnt an instance of Error', ->
    assert.throws (=> @sentry.error 'not an Error'), /error must be an instance of Error/

  it 'send error correctly', (done) ->
    scope = nock('https://app.getsentry.com')
      .matchHeader('X-Sentry-Auth'
      , "Sentry sentry_version=4, sentry_key=#{sentry_settings.key}, sentry_secret=#{sentry_settings.secret}, sentry_client=sentry-node/0.1.3")
      .filteringRequestBody (path) ->
        params = JSON.parse path
        if _.every(['culprit','message','logger','server_name','platform','level'], (prop) -> _.has(params, prop))
          if params.extra?.stacktrace?
            return 'error'
        throw Error 'Body of Sentry error request is incorrect.'
      .post("/api/#{sentry_settings.project_id}/store/", 'error')
      .reply(200, {"id": "534f9b1b491241b28ee8d6b571e1999d"}) # mock sentry response with a random uuid
             
    assert.doesNotThrow =>
      err = 
      @sentry.error new Error('Error message'), 'message', '/path/to/logger'
      scope.done()
    done()
    
  it 'send message correctly', (done) ->
    scope = nock('https://app.getsentry.com')
      .matchHeader('X-Sentry-Auth'
      , "Sentry sentry_version=4, sentry_key=#{sentry_settings.key}, sentry_secret=#{sentry_settings.secret}, sentry_client=sentry-node/0.1.3")
      .filteringRequestBody (path) ->
        params = JSON.parse path
        if _.every(['message','logger','level'], (prop) -> _.has(params, prop))
          unless _.some(['culprit','server_name','platform','extra'], (prop) -> _.has(params, prop))
            return 'message'
        throw Error 'Body of Sentry message request is incorrect.'
      .post("/api/#{sentry_settings.project_id}/store/", 'message')
      .reply(200, {"id": "c3115249083246efa839cfac2abbdefb"}) # mock sentry response with a random uuid
             
    assert.doesNotThrow =>
      @sentry.message 'message', '/path/to/logger'
      scope.done()
    done()
    
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
      
    @sentry.on 'error', ->
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

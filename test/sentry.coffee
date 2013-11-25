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
    
  it 'setup sentry client correctly', (done) ->
    assert.equal sentry_settings.key, @sentry.key
    assert.equal sentry_settings.secret, @sentry.secret
    assert.equal sentry_settings.project_id, @sentry.project_id
    assert.equal os.hostname(), @sentry.hostname
    assert.deepEqual ['production'], @sentry.enable_env
    done()
    
  it 'report error if credentials are missing', (done) ->
    assert.throws -> new Sentry {}
    , 'To use Sentry API, key, secret and project_id are required.'
    done()
    
  it 'send error correctly', (done) ->
    scope = nock('https://app.getsentry.com')
                .matchHeader('X-Sentry-Auth'
                , "Sentry sentry_version=4, sentry_key=#{sentry_settings.key}, sentry_secret=#{sentry_settings.secret}, sentry_client=sentry-node/0.1.0")
                .filteringRequestBody (path) ->
                  params = JSON.parse path
                  if _.every(['culprit','message','logger','server_name','platform','level'], (prop) -> _.has(params, prop))
                    if params.extra?.stacktrace?
                      return 'error'
                  throw Error 'Body of Sentry error request is incorrect.'
                .post("/api/#{sentry_settings.project_id}/store/", 'error')
                .reply(200, {"id": "534f9b1b491241b28ee8d6b571e1999d"}) # mock sentry response with a random uuid
                
    _this = @
    assert.doesNotThrow ->
      err = new Error 'Error message'
      _this.sentry.error err, 'message', '/path/to/logger'
      scope.done()
    done()
    
  it 'send message correctly', (done) ->
    scope = nock('https://app.getsentry.com')
                .matchHeader('X-Sentry-Auth'
                , "Sentry sentry_version=4, sentry_key=#{sentry_settings.key}, sentry_secret=#{sentry_settings.secret}, sentry_client=sentry-node/0.1.0")
                .filteringRequestBody (path) ->
                  params = JSON.parse path
                  if _.every(['message','logger','level'], (prop) -> _.has(params, prop))
                    unless _.some(['culprit','server_name','platform','extra'], (prop) -> _.has(params, prop))
                      return 'message'
                  throw Error 'Body of Sentry message request is incorrect.'
                .post("/api/#{sentry_settings.project_id}/store/", 'message')
                .reply(200, {"id": "c3115249083246efa839cfac2abbdefb"}) # mock sentry response with a random uuid
                
    _this = @
    assert.doesNotThrow ->
      _this.sentry.message 'message', '/path/to/logger'
      scope.done()
    done()
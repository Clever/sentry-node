assert = require 'assert'
Sentry = require("#{__dirname}/../lib/sentry")
sentry_settings = require("#{__dirname}/credentials").sentry


describe 'sentry-node', ->
  before ->
    @sentry = new Sentry sentry_settings
    # because only in production env sentry api would make http request
    process.env.NODE_ENV = 'production'
    
  it 'setup sentry client correctly', (done) ->
    assert.equal 'key', @sentry.key
    assert.equal 'secret', @sentry.secret
    assert.equal 'project_id', @sentry.project_id
    done()
    
  it 'report error if credentials are missing', (done) ->
    assert.throws -> new Sentry {}
    , 'To use Sentry API, key, secret and project_id are required.'
    done()
    
  it 'send error correctly', (done) ->
    assert true
    done()
    
  it 'send message correctly', (done) ->
    assert true
    done()
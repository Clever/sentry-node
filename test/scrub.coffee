_ = require 'underscore'
assert = require 'assert'
os = require 'os'
nock = require 'nock'

Sentry = require("#{__dirname}/../lib/sentry")
sentry_settings = require("#{__dirname}/credentials").sentry
scrub_lib = require ("#{__dirname}/../scrub")
user_scrub = require("#{__dirname}/lib/user_scrubber")


describe 'sentry-node', ->

  before ->
    @sentry = new Sentry sentry_settings
    # because only in production env sentry api would make http request
    process.env.NODE_ENV = 'production'

  it 'send error correctly with filtering', ->
    scope = nock('https://app.getsentry.com')
      .matchHeader('X-Sentry-Auth', "Sentry sentry_version=4, sentry_key=#{sentry_settings.key}, sentry_secret=#{sentry_settings.secret}, sentry_client=sentry-node")
      .filteringRequestBody (path) ->
        params = JSON.parse path
        if _.every(['culprit','message','logger','server_name','platform','level'], (prop) -> _.has(params, prop))
          if params.extra?.stacktrace? and not params.extra.password and params.extra.b is '[REDACTED]'
            return 'error'
        throw Error 'Body of Sentry error request is incorrect.'
      .post("/api/#{sentry_settings.project_id}/store/", 'error')
      .reply(200, {"id": "534f9b1b491241b28ee8d6b571e1999d"}) # mock sentry response with a random uuid

    scrubber = scrub_lib.Scrub 'default', [['password', 'user']]
    _sentry = new Sentry sentry_settings, scrubber
    _sentry.error new Error('Error message'), '/path/to/logger', 'culprit', {a:'a', b:'user name', password:'pwd'}
    scope.done()

  it 'scrubs keys with banned names', ->
    scrubber = scrub_lib.Scrub [scrub_lib.Scrubers.bad_keys], [['secret', 'password']]
    object =
      a : 'non sensitive'
      b :
        secret : 'shhhh'
        d : 'non sensitive'
        big_Secret: 'SHHHH'
      passwords :
        api: 'qwerty'

    expected = {a: 'non sensitive', b : {d: 'non sensitive'}}
    assert.deepEqual (scrubber object), expected

  it 'scrubs banned values', ->
    scrubber = scrub_lib.Scrub [scrub_lib.Scrubers.bad_vals], [['thisIsOurApiKey']]
    object =
      a: 'a string of text contains thisIsOurApiKey'
      b: 'a string of text contains thisisoutapikey'
      c: 'a normal string'
    expected =
      a: 'a string of text contains [REDACTED]'
      b: 'a string of text contains thisisoutapikey'
      c: 'a normal string'
    assert.deepEqual (scrubber object), expected


  it 'replaces sensitive url encoded info with [REDACTED]', ->
    scrubber = scrub_lib.Scrub [scrub_lib.Scrubers.url_encode], [['refresh_token', 'client_id', 'client_secret']]
    object =
      url: 'refresh_token=1234567890asdfghjkl&CliENT_Id=123456789.apps.googleusercontent.com&client_secret=123456789asdfghjkl&grant_type=refresh_token'
    expected = {url: '[REDACTED]&[REDACTED].apps.googleusercontent.com&[REDACTED]&grant_type=refresh_token'}
    assert.deepEqual (scrubber object), expected

  it 'replaces senstive info in string with [REDACTED]', ->
    scrubber = scrub_lib.Scrub [scrub_lib.Scrubers.plain_text], [['username']]
    object =
      a: 'Error: something went wrong'
      b: 'Error: Username 12345@example.com was taken'
      c: 'username 12345@example.com was taken'
      d: 'Error: Username 12345@example.com'
      e: 'Error: Username  =  12345@example.com'
      f: 'Error: Username'

    expected =
      a: 'Error: something went wrong'
      b: 'Error: [REDACTED] was taken'
      c: '[REDACTED] was taken'
      d: 'Error: [REDACTED]'
      e: 'Error: [REDACTED]'
      f: 'Error: Username'
    assert.deepEqual (scrubber object), expected

  it 'allows user defined functions', ->
    scrubber = scrub_lib.Scrub [user_scrub.scrub], [['these', 'arent', 'used']]
    object =
      a: 'good'
      omit_this_key: 'bad'
    expected =
      a: 'good'
    assert.deepEqual (scrubber object), expected

  it 'allows different illegal words for different functions', ->
    scrubber = scrub_lib.Scrub [scrub_lib.Scrubers.bad_keys, scrub_lib.Scrubers.url_encode, scrub_lib.Scrubers.plain_text], [['user'], ['id']]
    object =
      user: 'name'
      id: 'number'
      a: 'user'
      b: 'id 123456'
      c: 'someurl?id=12345&user=name'
    expected =
      id: 'number'
      a: 'user'
      b: '[REDACTED]'
      c: 'someurl?[REDACTED]&user=name'
    assert.deepEqual (scrubber object), expected

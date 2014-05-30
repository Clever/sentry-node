_ = require 'underscore'
_.mixin require 'underscore.deep'

Scrub = (bads, fns) ->
  bads = ['api_key', 'client_id', 'client_secret', 'refresh_token', 'user_token', 'user_token_secret',
    'password', 'secret', 'key', 'username', 'user', 'api'] if bads is 'default'
  fns = [Scrubers.bad_keys, Scrubers.url_encode, Scrubers.plain_text] if fns is 'default'

  scrub = (object) ->
    for fn in fns
      object = fn bads, object
    return object
  return scrub

Scrubers =
  bad_keys: (bads, object) ->
    object = _.deepToFlat object
    _.each (_.keys object), (key) ->
      _.each bads, (bad) ->
        reg_bad = new RegExp bad, 'i'
        if reg_bad.test key
          object = _.omit object, key
    return _.deepFromFlat object

  url_encode: (bads, object) ->
    object = _.deepToFlat object
    _.each (_.keys object), (key) ->
      i = object[key]
      _.each bads, (bad) ->
        # info can be encoded in the url in the form
        # <key>=<value> with . & ? field delimiters
        reg_bad = new RegExp "#{bad}=", 'i'
        delimiters = new RegExp "[.&?]"
        while (start = i.search reg_bad) != -1
          end = start + i[start..].search delimiters
          s = if not start then "[REDACTED]" else i[..start - 1] + "[REDACTED]"
          e = if end > start then i[end..] else ''
          i = s + e
      object[key] = i
    return _.deepFromFlat object

  plain_text: (bads, object) ->
    object = _.deepToFlat object
    _.each (_.keys object), (key) ->
      i = object[key]
      _.each bads, (bad) ->
        # Redact info in plain text
        delims = " ="
        delimiters = new RegExp "[#{delims}]"
        non_delimiters = new RegExp "[^#{delims}]"
        reg_bad = new RegExp "#{bad}[#{delims}]", 'i'
        while (start = i.search reg_bad) != -1 # start of the bad
          end1 = start + i[start..].search delimiters #end of the bad
          end2 = end1 + i[end1..].search non_delimiters #end of the delims
          end3 = end2 + i[end2..].search delimiters # next delim
          s = if not start then "[REDACTED]" else i[..start - 1] + "[REDACTED]"
          e = if end3 > end2 and end2 > end1 and end1 > start then i[end3..] else ''
          i = s + e
      object[key] = i
    return _.deepFromFlat object

module.exports = {Scrub, Scrubers}

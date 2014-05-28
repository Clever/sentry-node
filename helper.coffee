_ = require 'underscore'
_.mixin require 'underscore.deep'

module.exports =

  scrub: (object) ->

    # ensure that if y is a substring of x, y comes AFTER x in this list
    # what about _csrf and csrfSecret, id
    bads = ['api_key', 'client_id', 'client_secret', 'refresh_token', 'user_token', 'user_token_secret', 'password', 'secret', 'key', 'username', 'user', 'name', 'api']

    object = _.deepToFlat object

    # If bad is a substring of the key, omit that key
    _.each (_.keys object), (key) ->
      _.each bads, (bad) ->
        reg_bad = new RegExp bad, 'i'
        if reg_bad.test key
          object = _.omit object, key

    # for all the keys that are left, check their contents
    _.each (_.keys object), (key) ->
      i = object[key]
      _.each bads, (bad) ->
        # info can be encoded in the url in the form
        # <key>=<value> with . & ? field delimiters
        reg_bad = new RegExp bad + '=', 'i'
        delimiters = new RegExp /\.|&|\?/
        while (start = i.search reg_bad) != -1
          end = start + i[start..].search delimiters
          s = if not start then "[REDACTED]" else i[..start - 1] + "[REDACTED]"
          e = if end > start then i[end..] else ''
          i = s + e

        # info can also be included elsewhere. We will redact info in this form
        reg_bad = new RegExp bad, 'i'
        delimiters = new RegExp /[ =]/
        non_delimiters = new RegExp /[^ =]/ # NOT the stuff above
        while (start = i.search reg_bad) != -1 # start of the bad
          end1 = start + i[start..].search delimiters #end of the bad
          end2 = end1 + i[end1..].search non_delimiters #end of the delims
          end3 = end2 + i[end2..].search delimiters # next delim
          s = if not start then "[REDACTED]" else i[..start - 1] + "[REDACTED]"
          e = if end3 > end2 and end2 > end1 and end1 > start then i[end3..] else ''
          i = s + e

      object[key] = i
    object = _.deepFromFlat object
    return object

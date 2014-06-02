_ = require 'underscore'
_.mixin require 'underscore.deep'

Scrub = (fns, bads) ->
  fns = [Scrubers.bad_keys, Scrubers.url_encode, Scrubers.plain_text] if fns is 'default'
  scrub = (object) ->
    object = _.deepToFlat object
    _.each fns, (fn, i) -> # for each function
      bad_list = bads[i] or _.last bads # choose the badlist
      _.each bad_list, (bad) -> # for each bad
        object = fn bad, object
    return _.deepFromFlat object
  return scrub

Scrubers =
  bad_keys: (bad, object) ->
    _.each (_.keys object), (key) ->
      reg_bad = new RegExp bad, 'i'
      if reg_bad.test key
        object = _.omit object, key
    return object

  url_encode: (bad, object) ->
    _.each (_.pairs object), ([key, val]) ->
      # info can be encoded in the url in the form
      # <key>=<value> with . & ? field delimiters
      reg_bad = new RegExp "#{bad}=", 'i'
      delimiters = new RegExp "[.&?]"
      while (start = val.search reg_bad) != -1
        end = start + val[start..].search delimiters
        s = if not start then "[REDACTED]" else val[..start - 1] + "[REDACTED]"
        e = if end > start then val[end..] else ''
        val = s + e
      object[key] = val
    return object

  # If plain text and url_encode share bads, plain text should be called after url_encode
  plain_text: (bad, object) ->
    _.each (_.pairs object), ([key, val]) ->
      # Redact info in plain text
      delims = " ="
      delimiters = new RegExp "[#{delims}]"
      non_delimiters = new RegExp "[^#{delims}]"
      reg_bad = new RegExp "#{bad}[#{delims}]", 'i'
      while (start = val.search reg_bad) != -1 # start of the bad
        end1 = start + val[start..].search delimiters #end of the bad
        end2 = end1 + val[end1..].search non_delimiters #end of the delims
        end3 = end2 + val[end2..].search delimiters # next delim
        s = if not start then "[REDACTED]" else val[..start - 1] + "[REDACTED]"
        e = if end3 > end2 and end2 > end1 and end1 > start then val[end3..] else ''
        val = s + e
      object[key] = val
    return object

  bad_vals: (bad, object) ->
    _.each (_.pairs object), ([key, val]) ->
      object[key] = object[key].replace (bad), '[REDACTED]'
    return object

module.exports = {Scrub, Scrubers}

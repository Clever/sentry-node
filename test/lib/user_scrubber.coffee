_ = require 'underscore'

module.exports =
  scrub: (bad, object) ->
    return _.omit object, 'omit_this_key'


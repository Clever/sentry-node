_ = require 'underscore'
_.mixin require 'underscore.deep'

module.exports =
  scrub: (bads, object) ->
    return _.omit object, 'omit_this_key'


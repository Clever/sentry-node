var path = __dirname + '/' + (process.env.TEST_UNDERSTREAM_COV ? 'lib-js-cov' : 'lib-js') + '/sentry';
module.exports = require(path);
var rest = require('restler')
  ;

module.exports = {
  winston: require('winston'),
  u:      require('underscore'),
  async:  require('async'),
  util:   require('util'),
  inspect: require('util').inspect,
  format: require('util').format,
  rest: rest,
  getURL: function(url, options, callback) {
    if ( !callback ) {
      callback = options;
      options = {};
    }
    require('winston').info(url);
    rest.get(url, options).on('complete', function(result, response) {
      if ( result instanceof Error ) return callback(result);
      if ( response.statusCode !== 200 ) return callback(require('util').format("HTTP status code %s fetching %s", response.statusCode, require('util').inspect(url)));
      callback(null, result);
    });
  }
}

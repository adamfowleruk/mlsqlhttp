/*!
 * sqlite-parser
 * @copyright Code School 2015 {@link http://codeschool.com}
 * @author Nick Wronski <nick@javascript.com>
 */
 ;(function (parser) {
  function sqliteParser(source, callback) {
    try {
      callback(null, parser.parse(source));
    } catch (e) {
      callback(e);
    }
  }

  sqliteParser['NAME'] = 'sqlite-parser';
  sqliteParser['VERSION'] = '0.10.2';

  module.exports = sqliteParser;
//global is not defined in ML
//})(typeof self === 'object' ? self : global, require('./parser'));
})(require('./parser'));
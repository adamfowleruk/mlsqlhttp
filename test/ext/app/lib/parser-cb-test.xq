let $sql := "SeLECT `field`, 1 num_literal, 's' string_literal, ( select count(1) from triples.apples ) as result FROM documents.apples WHERE amount > 1"
let $result := xdmp:javascript-eval('var t_grammar = xdmp.elapsedTime();
var sqlp = require("src/ext/app/lib/parser.sjs");
var sampleSQL;
var t_parser = xdmp.elapsedTime();
var result = sqlp.parse(sampleSQL);
var t_result = xdmp.elapsedTime();
result = {
  "parser": t_parser,
  "t_result": t_result,
  "result":result
};
result;
', ('sampleSQL', $sql))
return $result;
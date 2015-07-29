xquery version "1.0-ml";

module namespace mlsqlc = "http://marklogic.com/sql/common";
declare default function namespace "http://marklogic.com/sql/common";

declare function parse($sql as xs:string) as node() {
  let $result := xdmp:javascript-eval('
    var sqlp = require("src/ext/app/lib/parser.sjs");
    var sql;
    sqlp.parse(sql);
    ', ('sql', $sql))
  return (xdmp:unquote(xdmp:quote($result))/statement)
};

declare function generateQuery($stmt as node()) as cts:query {
  let $tableQ := buildTableQuery($stmt/from)
  (: 
   : for some reason doing the or-query within buildTableQuery 
   : results in multiple or-queries instead of 1
   :)
  let $tableQ := if (count($tableQ) > 1) then
    cts:or-query(buildTableQuery($stmt/from))
  else
    $tableQ
  let $whereQ := convertQueryGroups($stmt/where)
  return cts:and-query(($tableQ, $whereQ))
};

declare %private function convertSqlToJson($sql as xs:string) as node() {
  let $result := xdmp:javascript-eval('
    var sqlp = require("src/ext/app/lib/parser.sjs");
    var sql;
    sqlp.parse(sql);
    ', ('sql', $sql))
  return xdmp:unquote(xdmp:quote($result))/statement
};

declare %private function convertSimpleQuery($node as node()) as cts:query {
  (: 
   : TODO:
   : 1. aliases
   :)
  let $field := $node/(left|right)[type = 'identifier']/name
  let $value := $node/(left|right)[type = 'literal']/value
  return
    try {
      (: use index if available :)
      let $indexTest := cts:element-reference(xs:QName($field))
      return cts:element-range-query(xs:QName($field), $node/operation, $value)
    } catch ($noIndexEx) {
      if ($node/operation = '=' or $node/operation = 'in' ) then
        (: else, fall back to something basic :)
        cts:element-value-query(xs:QName($field), $value)
      else
        (: reject if totally not possible :)
        error((), 'Use "=" or "in" (found: "'|| $node/operation ||'"), '
          || 'or create an index for this field: ' || $node/left/name)
    }
};

declare %private function convertQueryGroups($node as node()) as cts:query {
  (: for recursion :) 
  let $groups := convertQueryGroups($node/(left|right)[left/type/data() = 'expression'])
  (: for direct conversion :)
  let $simple := convertSimpleQuery($node/(left|right)[
      (left/type/data() = 'identifier' and right/type/data() = 'literal') or 
      (right/type/data() = 'identifier' and left/type/data() = 'literal')
    ])
  (: 
   : TODO:
   : 1. functions/aggregates
   : 2. inner query
   :)
  let $conditions := ($groups, $simple)
  return if ($node/operation = 'or') then
    cts:or-query($conditions)
  else if ($node/operation = 'and') then
    cts:and-query($conditions)
  else if (($node/left/type/data() = 'identifier' and $node/right/type/data() = 'literal') or 
      ($node/right/type/data() = 'identifier' and $node/left/type/data() = 'literal')) then
    convertSimpleQuery($node)
  else
    error((), 'Unexpected operation: "'|| $node/operation || '"'||count($simple))
};

declare %private function buildTableQuery($node as node()) as cts:query {
  for $source in $node[variant = 'table']/name
  let $tokens := tokenize($source, '\.')
  let $count := count($tokens)
  return if ($count = 1) then
      (: should we supply infinity as depth? :)
      cts:directory-query("/" || $tokens[1] || "/")
    else if ($count = 2) then
      if ($tokens[1] = 'collection') then
        cts:collection-query($tokens[2])
      else if ($tokens[1] = 'directory') then
        (: should we supply infinity as depth? :)
        cts:directory-query("/" || $tokens[1] || "/")
      else
        error((), 'Unexpected source: "'|| $source)
    else
      error((), 'Unexpected source: "'|| $source)
};
xquery version "1.0-ml";

module namespace mlsqlc = "http://marklogic.com/sql/select";
declare default function namespace "http://marklogic.com/sql/select";

import module namespace search = "http://marklogic.com/appservices/search"
     at "/MarkLogic/appservices/search/search.xqy";

(: start of actual select:)
declare function execute($stmt as node()) {
  let $query := generateQuery($stmt, xdmp:function(xs:QName("select")))
  let $hasFields := not(empty($stmt/result/*[type="identifier"])) 
    or $stmt/result/type = "identifier"
  let $hasFunctions := not(empty($stmt/result/*[type="function"]))
    or $stmt/result/type = "function"
  let $hasGroup := not(empty($stmt/group)) or $stmt/distinct = true()
  let $_ := xdmp:log(xdmp:quote($stmt))
  return 
  if ($hasGroup) then
    select-group($stmt, $query)
  else if ($hasFields) then
    select-basic($stmt, $query)
  else if ($hasFunctions) then
    select-aggregate($stmt, $query)
  else
    error((), 'Unhandled select scenario.')
};

declare %private function select-group($stmt as node(), $query as cts:query) {
  let $fields := (
    $stmt/group/expression/name
    , if ($stmt/distinct = true()) then $stmt/result[type="identifier"] else ()
    )
  let $refs := for $field in $fields return
    try {
       cts:element-reference(xs:QName($field))
    } catch ($e) {
      error((), 'Index required for group/distinct column: "'|| $field || '"')
    }
  (:
   : TODO:
   : 1. sort is defined by chronology of the $fields above
   : 2. paging is done via [x to y]
   :
   : However, sort is not necessarily via group fields.
   :)
  let $tuples := cts:value-tuples($refs, ("eager"), $query)
  (:
   : select the first that would match per tuple
   : now how do we handle * without a definition of expected fields somewhere...
   :)
  let $result := map:map()
  for $tuple in $tuples
  let $record := map:map()
  let $cond := cts:and-query(($query,
    for $field at $pos in $fields
    let $_ := map:put($record, $field, $tuple[$pos]) 
    return prepareSimpleQuery($field, "=", $tuple[$pos])
  ))
  (: for any non-distinct field, retrieve first value :)
  let $_ :=
    if ($stmt/distinct = true()) then () 
    else
      let $row := cts:search(/, $cond)[1]
      for $column in $stmt/result[type="identifier"][name != $fields]
      let $name := $column/name
      return 
        if ($column/variant = 'star') then
          process-star($record, $row)
        else if ($column/variant = 'column') then
          map:put($record, $name, $row/*[node-name() eq $name]/string())
        else
          error((), 'Unexpected column: "'|| $column || '"')
  (: for functions, use cond :)
  let $_ := 
    for $func in $stmt/result[type="function"]
    return processFunctions($record, $func, $cond)
  (: for literals :)
  let $_ := 
    for $field in $stmt/result[type="literal"]
    return map:put($record, $field/alias, $field/value)
  return $record 
};

declare %private function select-aggregate($stmt as node(), $query as cts:query) {
  let $record := map:map()
  let $_ := 
    for $func in $stmt/result[type="function"]
    return processFunctions($record, $func, $query)
  (: for literals :)
  let $_ := 
    for $field in $stmt/result[type="literal"]
    return map:put($record, $field/alias, $field/value)
  return $record 
};
  
declare %private function select-basic($stmt as node(), $query as cts:query) {  
  (:
   : TODO: This is where it gets tricky
   : 1. if select is all functions, then there is no 1 specific record to retrieve
   : 2. if select is mix of functions without group by, then function result is repeated for all values
   : 3. current implementation is applicable for proper mix of function and fields with proper group by.
   :)
  let $sort := buildSort($stmt/order)
  let $option :=
    <options xmlns="http://marklogic.com/appservices/search">
      <additional-query>{$query}</additional-query>
      {$sort}
    </options>
  (:
   : sql starts it's indexes with 0, xqy starts it's indexes with 1
   : 'offset' is actually the LIMIT of sqlite. parser is using the wrong keyword
   :)
  let $results := search:search(
      ""
      , $option
      , (xs:long($stmt/limit/start/value/data()) + 1)
      , ($stmt/limit/offset/value)
    )
  for $result in $results//search:result
  let $uri := $result/@uri
  let $_ := xdmp:log("uri to process: " || xdmp:quote($uri))
  return buildRow(doc($uri), $query, $stmt)  
};

declare %private function buildSort($sort as node()) as node()? {
  try {
    let $indexTest := cts:element-reference(xs:QName($sort/expression/name))
    let $field := '<element name="' || $sort/expression/name || '" />'
    let $direction := 
      if (exists($sort/direction) and matches($sort/direction, "^desc(ending)?$")) then
        ()
      else
        'direction="ascending"'
    let $result := '<sort-order ' || $direction || '>' || $field || '</sort-order>'
    return
      if (exists($sort)) then
        xdmp:unquote($result, "http://marklogic.com/appservices/search")
      else ()
  } catch ($noIndexEx) {
    error((), 'Index required for sort via column: "'|| $sort/expression/name || '"')
  }
};

declare %private function buildRow($row as node(), $query as cts:query, $stmt as node()) as map:map {
  let $uri := document-uri($row)
  let $row := $row/*[1]
  let $result := map:map()
  let $_ := 
    for $column in $stmt/result
    let $name := $column/name
    let $alias := $column/alias
    return
      if ($column/type = 'identifier') then
        if ($column/variant = 'star') then
          process-star($result, $row)
        else if ($column/variant = 'column') then
          map:put($result, $name, $row/*[node-name() eq $name]/string())
        else
          error((), 'Unexpected column: "'|| $column || '"')
      else if ($column/type = 'literal') then
        map:put($result, $alias, $column/value)
      else if ($column/type = 'function') then
        let $groupQuery := prepareGroupByQuery($row, $query, $stmt) 
        return processFunctions($result, $column, $groupQuery)
      else
        error((), 'Unexpected column: "'|| $column || '"')
  let $_ := map:put($result, "document-uri", $uri)
  return $result
};

declare %private function processFunctions($map as map:map, $column as node(), $query as cts:query) {
  let $alias := $column/alias
  (:
   : TODO: 
   : 1. find a better way to add the namespace prefix
   : 2. add more functions just by defining/declaring them in this file.
   :)
  let $result := xdmp:apply(
    xdmp:function(
      xs:QName("mlsqlc:"||lower-case($column/name))
      )
    , $column/args/name
    , $query)
  return map:put($map, $alias, $result)
};

declare %private function prepareGroupByQuery($row as node(), $query as cts:query, $stmt as node()) as cts:query {
  cts:and-query((
      $query,
      for $group in $stmt/group/expression[type = 'identifier']
      return 
        try {
          let $indexTest := cts:element-reference(xs:QName($group/name))
          return cts:element-range-query(xs:QName($group/name), "=", $row/*[node-name() eq $group/name]/string())
        } catch ($noIndexEx) {
          cts:element-value-query(xs:QName($group/name), $row/*[node-name() eq $group/name]/string())
        }
    ))
};

declare %private function count($field as xs:string, $groupByQuery as cts:query) as xs:anyAtomicType {
  try {
    (: use index if available :)
    xdmp:estimate(cts:search(/, $groupByQuery))
  } catch ($noIndexEx) {
    (: else, fall back to something basic :)
    count(cts:search(/, $groupByQuery))
  }
};

(: use of //* could result in "unpredictable" behavior later on :)
declare %private function max($field as xs:string, $groupByQuery as cts:query) as xs:anyAtomicType {
  try {
    (: use index if available :)
    cts:max(cts:element-reference(xs:QName($field)), (), $groupByQuery)
  } catch ($noIndexEx) {
    (: else, fall back to something basic :)
    fn:max(cts:search(/, $groupByQuery)//*[node-name() eq xs:QName($field)]/data())
  }
};

declare %private function min($field as xs:string, $groupByQuery as cts:query) as xs:anyAtomicType {
  try {
    (: use index if available :)
    cts:min(cts:element-reference(xs:QName($field)), (), $groupByQuery)
  } catch ($noIndexEx) {
    (: else, fall back to something basic :)
    fn:min(cts:search(/, $groupByQuery)//*[node-name() eq xs:QName($field)]/data())
  }
};

declare %private function avg($field as xs:string, $groupByQuery as cts:query) as xs:anyAtomicType {
  try {
    (: use index if available :)
    cts:avg-aggregate(cts:element-reference(xs:QName($field)), (), $groupByQuery)
  } catch ($noIndexEx) {
    (: else, fall back to something basic :)
    fn:avg(cts:search(/, $groupByQuery)//*[node-name() eq xs:QName($field)]/data())
  }
};

declare %private function process-star($map, $content) {
  for $n in $content/*
  let $count := count($n/*)
  return
    if( $count > 0) then process-star($map, $n)
    else map:put($map, string(node-name($n)), string($n))
};


(: start of where clause conversion :)
declare %private function generateQuery($stmt as node(), $selectCb as xdmp:function) as cts:query {
  let $tableQ := buildTableQuery($stmt/from)
  let $tableName := $stmt/from[variant = 'table']/name
  (: 
   : for some reason doing the or-query within buildTableQuery 
   : results in multiple or-queries instead of 1
   :)
  let $tableQ := if (count($tableQ) > 1) then
    cts:or-query(buildTableQuery($stmt/from))
  else
    $tableQ
  let $whereQ := convertQueryGroups($tableName, $stmt/where, $selectCb, false())
  return cts:and-query(($tableQ, $whereQ))
};

declare %private function convertQueryGroups($tableName as xs:string, $node as node(), $selectCb as xdmp:function, $isJoin as xs:boolean) as cts:query {
  (: for recursion :) 
  let $groups := convertQueryGroups($tableName, $node/(left|right)[left/type/data() = 'expression'], $selectCb, $isJoin)
  (: for direct conversion :)
  let $simple := convertSimpleQuery($node/(left|right)[
      (left/type/data() = 'identifier' and right/type/data() = 'literal') or 
      (right/type/data() = 'identifier' and left/type/data() = 'literal')
    ])
  (: 
   : TODO:
   : 1. functions/aggregates
   :)
  let $conditions := ($groups, $simple)
  return if ($node/operation = 'or') then
    cts:or-query($conditions)
  else if ($node/operation = 'and') then
    cts:and-query($conditions)
  else if (($node/left/type/data() = 'identifier' and $node/right/type/data() = 'literal') or 
      ($node/right/type/data() = 'identifier' and $node/left/type/data() = 'literal')) then
    convertSimpleQuery($node)
  else if (($node/left/type/data() = 'identifier' and $node/right/type/data() = 'statement') or 
      ($node/right/type/data() = 'identifier' and $node/left/type/data() = 'statement')) then
    buildSelectQuery($node, $selectCb)
  else if ($node/left/variant = 'column' and $node/right/variant = 'column') then
    if ($isJoin) then 
      if (contains($node/left/name, $tableName||'.')) then
        cts:element-query(xs:QName(getTableName($node/left/name)), cts:and-query(())) 
      else
        cts:element-query(xs:QName(getTableName($node/right/name)), cts:and-query(()))
    else 
      error((), 'Field to field not supported: "'|| $node || '"')
  else
    error((), 'Unexpected operation: "'|| $node || '"')
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
   : 2. prefixes, review
   :)
  let $field := $node/(left|right)[type = 'identifier']/name
  let $tokens := tokenize($field, '\.')
  let $field := 
    if (count($tokens) > 1) then
      $tokens[2]
    else 
      $field
  let $value := $node/(left|right)[type = 'literal']/value
  return prepareSimpleQuery($field, $node/operation, $value)
};

declare %private function prepareSimpleQuery($field as xs:string, $operation as xs:string, $value as xs:anyAtomicType*) as cts:query {
  (:
   : TODO:
   : 1. handle 'like' $operation
   : 2. handle 'rlike' $operation
   : 3. handle 'null', i.e. 'is not null' or 'is null'
   :)
  let $newOp := replace($operation, "^not\s+|\s+not$|^!", "")
  let $not := ($operation != $newOp)
  let $newOp := 
    if ($newOp = 'in' or $newOp = 'is') then
      '='
    else if ($newOp = '<>') then
      '!='
    else
      $newOp 
  let $tempResult := 
    try {
      (: use index if available :)
      let $indexTest := cts:element-reference(xs:QName($field))
      return cts:element-range-query(xs:QName($field), $newOp, $value)
    } catch ($noIndexEx) {
      if ($newOp = '=' or $newOp = 'in' ) then
        (: else, fall back to something basic :)
        cts:element-value-query(xs:QName($field), $value)
      else
        (: reject if totally not possible :)
        error((), 'Use "=" or "in" (found: "'|| $newOp ||'"), '
          || 'or create an index for this field: ' || $field)
    }
  let $tempResult :=
    if ($not) then
      cts:not-query($tempResult)
    else
      $tempResult
   return $tempResult
};

declare %private function buildSelectQuery($node as node(), $selectCb as xdmp:function) as cts:query {
  let $field := $node/(left|right)[type='identifier']/name
  let $result := xdmp:apply($selectCb, $node/(left|right)[type='statement'])[1]
  let $value := map:get($result, map:keys($result)[1])
  return prepareSimpleQuery($field, $node/operation, $value)
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
      else if ($tokens[1] = 'documents') then
        (: should we supply infinity as depth? :)
        cts:directory-query("/" || $tokens[2] || "/")
      else
        error((), 'Unexpected source: "'|| $source)
    else
      error((), 'Unexpected source: "'|| $source)
};

declare %private function getTableName($tableName as xs:string) as xs:string {
  let $parts := tokenize($tableName, '\.')
  return
    if (count($parts) < 2) then
      $tableName
    else
      $parts[2]
};
xquery version "1.0-ml";

module namespace mlsqls = "http://marklogic.com/sql/select";
declare default function namespace "http://marklogic.com/sql/select";

import module namespace mlsqlc = "http://marklogic.com/sql/common" at 'sql-common.xq';
import module namespace search = "http://marklogic.com/appservices/search"
     at "/MarkLogic/appservices/search/search.xqy";

declare function select($sql as xs:string) {
  let $stmt := mlsqlc:parse($sql)
  return selectParsed($stmt)
};

declare function selectParsed($stmt as node()) {
  let $query := mlsqlc:generateQuery($stmt, xdmp:function(xs:QName("mlsqlc:selectParsed")))
  let $sort := buildSort($stmt/order)
  let $option :=
    <options xmlns="http://marklogic.com/appservices/search">
      <additional-query>{$query}</additional-query>
      {$sort}
    </options>
  (:
   : sql starts it's indexes with 0, ml starts it's indexes with 1
   : 'offset' is actually the LIMIT of sqlite. parser is using the wrong keyword
   :)
  for $result in search:search("", $option, 
    (xs:long($stmt/limit/start/value/data()) + 1), 
    ($stmt/limit/offset/value))//search:result
  (:
   : should we consider each source? 
   :)
  return buildRow(doc($result/@uri)/*[1], $query, $stmt)  
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
  let $result := map:map()
  let $result := 
    for $column in $stmt/result
    let $name := $column/name
    let $alias := $column/alias
    (:
     : TODO: 
     : 1. support inner queries
     :)
    return
      if ($column/type = 'identifier') then
        if ($column/variant = 'star') then
          allImmediate($row)
        else if ($column/variant = 'column') then
          map:new(
            map:entry($name, $row/*[node-name() eq $name]/string())
          )
        else
          error((), 'Unexpected column: "'|| $column || '"')
      else if ($column/type = 'literal') then
        map:new(
            map:entry($alias, $column/value)
          )
      else if ($column/type = 'function') then
        processFunctions($row, $column, $query, $stmt)
      else
        error((), 'Unexpected column: "'|| $column || '"')
  return map:new($result)
};

declare %private function processFunctions($row as node(), $column as node(), $query as cts:query, $stmt as node()) as map:map {
  (:
   : TODO: 
   : 1. support more functions
   :)
  let $groupQuery := prepareGroupByQuery($row, $query, $stmt)
  let $alias := $column/alias
  let $result := 
    if ($column/name = 'count') then
      doCount($groupQuery)
    else if ($column/name = 'max') then
      doMax($column/args/name, $groupQuery)
    else if ($column/name = 'min') then
      doMin($column/args/name, $groupQuery)
    else if ($column/name = 'avg') then
      doAvg($column/args/name, $groupQuery)
    else
      error((), 'Unexpected function: "'|| $column || '"')
  return map:new(
      map:entry($alias, $result)
    )
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

declare %private function doCount($groupByQuery as cts:query) as xs:anyAtomicType {
  try {
    (: use index if available :)
    xdmp:estimate(cts:search(/, $groupByQuery))
  } catch ($noIndexEx) {
    (: else, fall back to something basic :)
    count(cts:search(/, $groupByQuery))
  }
};

(: use of //* could result in "unpredictable" behavior later on :)
declare %private function doMax($field as xs:string, $groupByQuery as cts:query) as xs:anyAtomicType {
  try {
    (: use index if available :)
    cts:max(cts:element-reference(xs:QName($field)), (), $groupByQuery)
  } catch ($noIndexEx) {
    (: else, fall back to something basic :)
    fn:max(cts:search(/, $groupByQuery)//*[node-name() eq xs:QName($field)]/data())
  }
};

declare %private function doMin($field as xs:string, $groupByQuery as cts:query) as xs:anyAtomicType {
  try {
    (: use index if available :)
    cts:min(cts:element-reference(xs:QName($field)), (), $groupByQuery)
  } catch ($noIndexEx) {
    (: else, fall back to something basic :)
    fn:min(cts:search(/, $groupByQuery)//*[node-name() eq xs:QName($field)]/data())
  }
};

declare %private function doAvg($field as xs:string, $groupByQuery as cts:query) as xs:anyAtomicType {
  try {
    (: use index if available :)
    cts:avg-aggregate(cts:element-reference(xs:QName($field)), (), $groupByQuery)
  } catch ($noIndexEx) {
    (: else, fall back to something basic :)
    fn:avg(cts:search(/, $groupByQuery)//*[node-name() eq xs:QName($field)]/data())
  }
};

declare %private function allImmediate($row as node()) as map:map {
  let $result := map:map()
  let $_ := 
    for $column in $row/*
    return map:put($result, $column/name(), $column/string()) 
  return $result
};
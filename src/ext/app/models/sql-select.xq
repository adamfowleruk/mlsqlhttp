xquery version "1.0-ml";

module namespace mlsqls = "http://marklogic.com/sql/select";
declare default function namespace "http://marklogic.com/sql/select";

import module namespace mlsqlc = "http://marklogic.com/sql/common" at 'sql-common.xq';

declare function select($sql as xs:string) as map:map* {
  let $stmt := mlsqlc:parse($sql)
  return selectParsed($stmt)
};

declare function selectParsed($stmt as node()) as map:map* {
  let $query := mlsqlc:generateQuery($stmt)
  for $doc in cts:search(/, $query)
  (:
   : should we consider each source? 
   :)
  return buildRow($doc/*[1], $query, $stmt)
};

declare %private function buildRow($row as node(), $query as cts:query, $stmt as node()) as map:map {
  let $result := map:map()
  let $result := 
    for $column in $stmt/result
    let $name := $column/name
    let $alias := 
      if (not(empty($column/alias))) then
        $column/alias
      else 
        $name
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
  let $alias :=
    if (not(empty($column/alias))) then
      $column/alias 
    else
      (: there has got to be a better way to construct this :)
      $column/name || '(' || $column/args/(name|value) || ')'
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
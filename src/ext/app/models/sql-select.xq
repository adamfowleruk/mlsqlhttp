xquery version "1.0-ml";

module namespace mlsqls = "http://marklogic.com/sql/select";
declare default function namespace "http://marklogic.com/sql/select";

import module namespace mlsqlc = "http://marklogic.com/sql/common" at 'sql-common.xq';

declare function select($sql as xs:string) as map:map {
  let $stmt := mlsqlc:parse($sql)
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
      if ($column/alias != () and not(empty($column/alias))) then
        $column/alias
      else if (not(empty($name))) then
        $name
      else 
        $column/value
    (:
     : TODO: 
     : 1. support more functions
     : 2. support inner queries
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
        if ($column/name = 'count') then
          map:new(
              map:entry($alias, doCount($row, $query, $stmt))
            )
        else
          error((), 'Unexpected function: "'|| $column || '"')
      else
        error((), 'Unexpected column: "'|| $column || '"')
  return map:new($result)
};

declare %private function doCount($row as node(), $query as cts:query, $stmt as node()) as xs:int {
  let $finalQuery := cts:and-query((
      $query,
      for $group in $stmt/group/expression[type = 'identifier']
      return cts:element-value-query(xs:QName($group/name), $row/*[node-name() eq $group/name]/string())
    ))
  let $_ := xdmp:log('review query: ' || $finalQuery)
  return
    try {
      (: use index if available :)
      xdmp:estimate(cts:search(/, $finalQuery))
    } catch ($noIndexEx) {
      (: else, fall back to something basic :)
      count(cts:search(/, $finalQuery))
    }
};

declare %private function allImmediate($row as node()) as map:map {
  let $result := map:map()
  let $_ := 
    for $column in $row/*
    return map:put($result, $column/name(), $column/string()) 
  return $result
};
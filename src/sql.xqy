xquery version "1.0-ml";

module namespace mlsql = "http://marklogic.com/sql";
declare default function namespace "http://marklogic.com/sql";

import module namespace select = "http://marklogic.com/sql/select" at "/select.xqy";
import module namespace transform = "http://marklogic.com/sql/result/transform" at "/transform.xqy";

declare function execute($sql as xs:string?, $params as map:map) as document-node()? {
  let $stmt := parse($sql)
  return xdmp:apply(
    xdmp:function(
      xs:QName("mlsql:"||lower-case($stmt/variant))
      )
    , $stmt
    , $params)
};

declare %private function parse($sql as xs:string) as node() {
  let $result := xdmp:javascript-eval('
    var sqlp = require("ext/parser.sjs");
    var sql;
    sqlp.parse(sql);
    ', ('sql', $sql))
  return (xdmp:unquote(xdmp:quote($result))/statement)
};

declare %private function select($stmt as node(), $params as map:map) as document-node()? {
  transform:convert-map( 
    select:execute(
      $stmt
    )
    , map:get($params, "format")
  )
};

(:
 : TODO: support
 : 1. create table
 : 2. insert
 : 3. update
 : 4. delete
 : 5. alter table
 :)
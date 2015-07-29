xquery version "1.0-ml";

import module namespace mlsqlc = "http://marklogic.com/sql/common" at 'src/ext/app/models/sql-common.xq';

let $sql := "
  SeLECT *, name, count(1), 1
  FROM person
  WHERE (age = 19)
  group by gender"
let $stmt := mlsqlc:parse($sql)
return ($stmt, mlsqlc:generateQuery($stmt))
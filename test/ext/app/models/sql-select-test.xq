xquery version "1.0-ml";

import module namespace mlsqls = "http://marklogic.com/sql/select" at 'src/ext/app/models/sql-select.xq';

let $sql := "
  SeLECT *, name, count(1), 1
  FROM person
  WHERE (age = 19)
  group by gender" 
return mlsqls:select($sql)
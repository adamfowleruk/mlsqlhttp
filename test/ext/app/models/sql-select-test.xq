xquery version "1.0-ml";

import module namespace mlsqls = "http://marklogic.com/sql/select" at 'src/ext/app/models/sql-select.xq';
import module namespace mlsqlc = "http://marklogic.com/sql/common" at 'src/ext/app/models/sql-common.xq';

let $sql := "
  SeLECT *, name, max(age) maxage, 1, count(age), avg(height)
  FROM documents.person
  WHERE age >= (
    select avg(age)
    from person
  )
  and gender in ('F','M')
  and gender is not null
  and gender != 'F'
  and gender in (
    select gender
    from person
  )
  group by gender
  order by age
  limit 1, 2 
  " 
return (mlsqls:select($sql), mlsqlc:parse($sql))
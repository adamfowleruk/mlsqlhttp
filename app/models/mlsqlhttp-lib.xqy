xquery version "1.0-ml";

declare module namespace m="http://marklogic.com/sql/mlsqlhttp";

(:
 : Entry point for entire mlsqlhttp module. ALWAYS call this function with appropriate parameters.
 : All other methods are subject to change without notice.
 : Either returns a string or xml node (map).
 :)
declare function m:process($sql as xs:string,$sqlformat as xs:string,$returnformat as xs:string) as node {
  let $result :=
    m:perform-query(
      if ("application/sql" eq $sqlformat) then
        m:process-ansi-sql($sql)
      else
       <m:parse-error><m:message>Unsupported query format : {$sqlformat} , use "application/sql" instead</m:message></m:parse-error>
    )
  return
    if (fn:not(fn:empty($result/m:parse-error))) then
      <m:response>{$result}</m:response>
    else
      if (fn:not(fn:empty($result/m:query))) then
        if ("text/plain" eq $returnformat) then
          m:reformat-cli($result)
        else
          if ("application/json" eq $returnFormat) then
            m:reformat-json($result)
          else
            if ("text/csv" eq $returnformat) then
              m:reformat-csv($result)
            else
              if ("text/xml" eq $returnformat) then
                m:reformat-xml($result)
              else
                <m:response><m:formatting-error>
                  <m:message>Unsupported return format : {$returnformat} , must be one of : text/plain OR application/json
                  OR text/xml OR text/csv</m:message></m:formatting-error>
                </m:response>
      else
        (: TODO other request types E.g. insert :)
        <m:response><m:invocation-error><m:message>SQL operation not supported. Must be one of : INSERT</m:message></m:invocation-error></m:response>
};


















(: QUERY PARSERS :)

(:
 : Performs a standards ANSI SQL query. Returns the map prior to reformatting.
 : Map contains result set row ids as the key (as a string), and another map as the value.
 : Each row map contains the final result fields as the key, and the values as values.
 : Values could include an XML or JSON element as well as intrinsic results. The reformatter determines how these are returned.
 :)
declare function m:process-ansi-sql($sql as xs:string) as map:map {
  map:map()
};



(:
 : We may want to support a non-standard ANSI SQL. E.g. for projection to target JSON or XML or MATCH keyword and so on.
 :)
declare function m:process-ml-sql($sql as xs:string) as map:map {
  map:map()
};











(:
Request definition after parsing

SELECT:-

<query xmlns="http://marklogic.com/sql/mlsqlhttp">
 <type>select</type>
 <fields all="false">
  <field><name>city</name><operation>value</operation></field>
  <field><name>temp</name><operation>value</operation></field>
  <field><name>month</name><operation>value</operation></field>
 </fields>
 <sources>
  <source><type>documents</type><restriction>temperatures</restriction><named/></source> <!-- named is for renaming result parent with AS keyword -->
 </sources>
 <terms>
  <term><field>city</field><operator>=</operator><value>Derby</value>
  <!-- must also support () and complex containment. Holds the SQL view of the query, NOT the marklogic view -->
 </terms>
 <limit start="1" end="10" />
</query>
:)












(: QUERY PERFORMERS :)

(:
 : Handles all final query performances.
 :)
declare function m:perform-query($query as element(m:query) ) as map:map {
  let $map := map:map()
  let $putcount := map:put($map,"count",xs:string(0))
  let $output :=
  if ("documents" eq $query/m:sources/m:source[1]/type) then
    (: cts search :)
    for $result at $pos in cts:search(
        (: collection :)
        fn:collection($query/m:sources/m:source[1]/m:restriction/text())
        ,
        (: query :)


        (: TODO REMOVE THIS DEBUG LINE AND MATCHING PAREN :)
        map:put($map,"query",



        if (fn:empty($query/m:sources/m:source[1]/m:terms)) then
          cts:and-query(
            for $clause in $query/m:sources/m:source[1]/m:terms
            return
              (: CLAUSE TO COPY BEGIN :)
              if ($clause/m:operator eq "=") then
                cts:element-value-query(xs:QName(xs:string($clause/m:field)),xs:string($clause/m:value)) (: TODO support multiple values if in ANSI spec :)
              else if ($clause/m:operator eq ("!=","<>")) then
                cts:not-query(cts:element-value-query(xs:QName(xs:string($clause/m:field)),xs:string($clause/m:value))) (: TODO support multiple values if in ANSI spec :)
              else if ($clause/m:operator eq ("<",">","<=",">=")) then
                cts:element-range-query(xs:QName(xs:string($clause/m:field)),xs:string($clause/m:operator),xs:string($clause/m:value)) (: TODO error on no range index :)
              else
                () (: TODO error here on invalid operator :)
              (: CLAUSE TO COPY ENDS :)
          )
        else
          () (:cts:not-query():) (: TODO validate with Mary that this is the most performant way to select everything :)
        ),
        (: options :)
        ()
      )[xs:integer($query/m:limit/@start) to xs:integer($query/m:limit/@end)]
    return
      let $rowmap := map:map()
      let $newrow := map:put($map,xs:string($pos + $start - 1),$rowmap)
      let $puturi := map:put($rowmap,"_uri",fn:base-uri($result))
      let $putcount := map:put($map,"count",xs:integer(map:get($map,"count")) + 1)
      return
        if (fn:not(fn:empty($selectedFields))) then
          for $field in $selectedFields
          return map:put($rowmap,$field,
            (: TODO reformat the below and check it's child - don't return the xml element itself unless a complex element :)
            xdmp:unpath(fn:concat("fn:doc(""" , fn:base-uri($result) , """)/", $field)) (: Check performance of this. It's used in Norm so should be ok. :)
          )
        else
          (: no fields specified - must extract from documents' top level elements - E.g. select * from query :)
          for $child in $result
          return
            map:put($rowmap,xs:string(fn:node-name($child)),$child) (: TODO use value of element, not element itself :)
  else
    (: sparql :)
    ()

  (: TODO error handling on no range indexes, out of memory etc :)
  return $map
};





(: RESULT REFORMATTERS :)

(:
 : Reformats the result as a multi line string in the same manner as many RDBMS' command line interface, hence cli.
 :)
declare function m:reformat-cli($map as map:map) as node {
  m:reformat-text($map,"",(),"\n",""|","|","|")
};

declare function m:reformat-xml($map as map:map) as node {
  (<xml>{$map}</xml>)/*
};

declare function m:reformat-csv($map as map:map) as node {
  m:reformat-text($map,"""","\\""","\n",",","","")
};

declare function m:reformat-json($map as map:map) as node {
  let $fieldmap := map:map()
  let $putcount := map:put($fieldmap,"count","0")
  let $lines :=
    for $rowid in (1 to xs:integer(map:get($map,"count")))
    let $rowmap := map:get($map,xs:string($rowid))
    return
    (
      fn:concat("{",
        for $key at $keypos in $rowmap
        let $fieldvalue := map:get($rowmap,$key)
        return
        (
          if ($keypos gt 1) then "," else ()
          ,
          fn:concat("""",$key,""":""",xs:string($fieldvalue),"""") (: TODO support complex XML elements within JSON as string escaped XML :)
        )
      ,"}")
    )
  return
    fn:concat("{""response"":{""results"":[", $lines ,"]} }")
};

declare function m:reformat-text($map as map:map,$charquote as xs:string,$charescape as xs:string,$eol as xs:string,
  $fieldsep as xs:string,$startsep as xs:string,$endsep as xs:string) as node {

  let $fieldmap := map:map()
  let $putcount := map:put($fieldmap,"count","0")
  let $lines :=
    for $rowid in (1 to xs:integer(map:get($map,"count")))
    let $rowmap := map:get($map,xs:string($rowid))
    return
      for $key in $rowmap
      let $fieldvalue := map:get($rowmap,$key)
      return
        (
        if (fn:empty($fieldValue)) then
          let $newcount := xs:integer(map:get($fieldmap,"count")) + 1
          let $putfield := map:put($fieldmap,xs:string($newcount),$key)
          let $putcount := map:put($fieldmap,"count",$newcount)
        else
          ()
        ,
        (: return actual line values now :)
        (: could do now as we know we must have all fields' positions already :)
        fn:concat($startsep,(
        for $fieldcount in (1 to map:get($fieldmap,"count"))
        return
          fn:concat(
            (if ($fieldcount gt 1) then $fieldsep else () ),
            $charquote,map:get($rowmap,map:get($fieldmap,xs:string($fieldcount))),$charquote (: TODO replace single quotes with escaped characters :)
          )
        ),$endsep,$eol)
        )
  return
    text {
      fn:concat(
        (: row headers :)
        fn:concat($startsep,(
          for $fieldcount in (1 to map:get($fieldmap,"count"))
          return
            fn:concat(
              (if ($fieldcount gt 1) then $fieldsep else () ),
              $charquote,map:get($fieldmap,xs:string($fieldcount)),$charquote
            )
        ),$endsep,$eol)
        ,
        (: row data :)
        $lines
      )
    }
};











(: TODO UPDATE/INSERT PERFORMERS :)



(: TODO UPDATE/INSERT RESPONSE REFORMATTERS :)

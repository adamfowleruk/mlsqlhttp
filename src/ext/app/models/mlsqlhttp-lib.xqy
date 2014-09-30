declare xquery "1.0-ml";

declare module namespace m="http://marklogic.com/sql/mlsqlhttp";

(:
 : Entry point for entire mlsqlhttp module. ALWAYS call this function with appropriate parameters.
 : All other methods are subject to change without notice.
 : Either returns a string or xml node (map).
 :)
declare function m:process($sql as xs:string,$sqlformat as xs:string,$returnformat as xs:string) as node {
  (: TODO switch on sqlformat and return format :)
  m:reformat-cli(m:perform-query(m:process-ansi-sql($sql)))
};



(: QUERY PARSERS :)

(:
 : Performs a standards ANSI SQL query. Returns the map prior to reformatting.
 : Map contains result set row ids as the key (as a string), and another map as the value.
 : Each row map contains the final result fields as the key, and the values as values.
 : Values could include an XML or JSON element as well as intrinsic results. The reformatter determines how these are returned.
 :)
declare function m:process-ansi-sql($sql as xs:string) as element(map:map) {

};







(:
Request definition after parsing

<query xmlns="http://marklogic.com/sql/mlsqlhttp">
 <type>select</type>
 <fields all="false">
  <field><name>city</name><operation>value</operation></field>
  ...
 </fields>
 <sources>
  <source><type>documents</type><restriction>temperatures</restriction><named/></source> <!-- named is for renaming result parent with AS keyword -->
  ...
 </sources>
 <terms>
  <term><name>city</name><operator>=</operator><value>Derby</value>
  ... <!-- must also support () and complex containment. Holds the SQL view of the query, NOT the marklogic view -->
 </terms>
 <limit start="1" end="10" />
</query>

:)







(: QUERY PERFORMERS :)

(:
 : Handles all final query performances.
 :)
declare function m:perform-query($selectedFields as xs:string*,$sourceData as xs:string,$sourceRestriction as xs:string?
  $whereClauses as element(m:where)*,$start as xs:integer,$end as xs:integer
) as element(map:map) {
  let $map := map:map()
  let $output :=
  if ("documents" eq $sourceData) then
    (: cts search :)
    for $result at $pos in cts:search(
        (: collection :)
        fn:collection($sourceRestriction)
        ,
        (: query :)
        if (fn:count($whereClauses gt 1)) then
          cts:and-query(

          )
        else
          if ($whereClauses) then

          else
            cts:not-query()
        ,
        (: options :)
        ()
      )[$start to $end]
    return
      let $rowmap := map:map()
      let $newrow := map:put($map,xs:string($pos + $start - 1),$rowmap)
      let $puturi := map:put($rowmap,"_uri",fn:base-uri($result))
      return
        for $field in $selectedFields
        return map:put($rowmap,$field,
          (: TODO reformat the below and check it's child - don't return the xml element itself unless a complex element :)
          xdmp:unpath(fn:concat("fn:doc(""" , fn:base-uri($result) , """)/", $field)) (: Check performance of this. It's used in Norm so should be ok. :)
        )
  else
    (: sparql :)
    ()

  return $map
};






(: RESULT REFORMATTERS :)

(:
 : Reformats the result as a multi line string in the same manner as many RDBMS' command line interface, hence cli.
 :)
declare function m:reformat-cli($map as element(map:map)) as xs:string {

};

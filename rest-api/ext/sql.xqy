xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/sql";

import module namespace m = "http://marklogic.com/ext/app/models/mlsqlhttp-lib" at "/ext/app/models/mlsqlhttp-lib.xqy";

declare namespace roxy = "http://marklogic.com/roxy";

declare
%roxy:params("")
function ext:post(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()*
{
(:
        let $config := json:config("custom")
        let $cx := map:put( $config, "text-value", "label" )
        let $cx := map:put( $config , "camel-case", fn:false() )
        let $cx := map:put($config, "array-element-names",(xs:QName("m:schema"),xs:QName("m:table"),xs:QName("m:column"),xs:QName("m:relationship"),xs:QName("m:docuri")))
        let $cx := map:put($config, "element-namespace","http://marklogic.com/roxy/models/rdb2rdf")
        let $cx := map:put($config, "element-namespace-prefix","m")
        let $cx := map:put($config, "element-prefix","p")
  let $preftype := if ("application/xml" = map:get($context,"accept-types")) then "application/xml" else "application/json"
  let $l := xdmp:log($input)
  let $l := xdmp:log(map:get($context,"input-types"))
  let $inxml :=
    if ("application/xml" = map:get($context,"input-types")) then
      $input
    else
      json6:transform-from-json($input/text(),$config)
  let $l := xdmp:log($inxml)
  let $out := m:rdb2rdf-direct-partial($inxml)
  let $outlog := map:put($context, "output-types", $preftype)
  return
    (xdmp:set-response-code(200, "OK"),xdmp:commit(),
      if ("application/xml" = $preftype) then
        document{$out}
      else
        document{json6:transform-to-json($out,$config)}
    )
:)



  document {
    m:process(
      $input/text(),
      (map:get($context,"input-types"),"application/sql")[1],
      (map:get($context,"accept-types"),"text/plain")[1]
    )
  }
};

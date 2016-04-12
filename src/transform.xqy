xquery version "1.0-ml";

module namespace mlsqltrans = "http://marklogic.com/sql/result/transform";
declare default function namespace "http://marklogic.com/sql/result/transform";

declare function convert-map($map as map:map*, $format as xs:string?) {
  let $format := lower-case($format)
  let $format := 
    if (empty($format) or not($format = ("csv", "xml", "json"))) then
      "json" 
    else $format
  return xdmp:apply(
    xdmp:function(
      xs:QName("mlsqltrans:"||$format)
      )
    , ($map))
};

declare %private function csv($maps as map:map*) as document-node()? {
  let $keys := map:keys($maps[1])
  return document {
    string-join(
      (
        string-join($keys, ",")
        , map-to-csv($maps, $keys)
      )
      (: '&#xa;' is new line :)
      , '&#xa;'
    )
  }
};

declare %private function map-to-csv($map as map:map, $keys as xs:string*) as xs:string? {
  string-join(
    (
      for $key in $keys
      return string(map:get($map, $key))
    ), ","
  )
};

declare %private function json($maps as map:map*) as document-node()? {
  xdmp:to-json($maps)
};

(: there ought to be a built in way to do this. :)
declare %private function xml($maps as map:map*) as document-node()? {
  document {
    <records>{map-to-xml($maps)}</records>
  }
};

declare %private function map-to-xml($map as map:map) as node()? {
  <record>
  {
    for $key in map:keys($map)
    let $elemName := filter-xml-elem-name($key)
    return element {$elemName} {
      (: add an alias attr if they differ :)
      if ($elemName != $key) then attribute alias {$key} else ()
      , string(map:get($map, $key))
    } 
  }
  </record>
};

(: a simplistic approach to make sure the element name is valid :)
declare %private function filter-xml-elem-name($name as xs:string?) as xs:string {
  let $name := 
  if (matches($name, "^[1-9].*")) then
    concat("_", $name)
  else
    $name
  return replace($name, "[^a-zA-Z0-9-]", "_")
};
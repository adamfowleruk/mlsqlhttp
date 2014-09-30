# Design of mlsqlhttp

## Select query syntax

```sql
SELECT [field list|*] FROM [triples|blank for documents].[RDF Type|collection]
WHERE [predicate|element] [=|<|>|<=|>=] LIMIT [start,]length
```

### Examples

```sql
SELECT * FROM temperatures WHERE city='Derby'
```

Generates

```xquery
cts:search(fn:collection(temperatures),
  cts:element-value-query(xs:QName("city"),"Derby")
)
```

Returns

| uri | city | temperature | month |
| --- | --- | --- | --- |
| /temperatures/1 | Derby | 12 | Jun |
| /temperatures/2 | Derby | 14 | Apr |

```sql
SELECT AVG(temp) FROM temperatures WHERE month='Jun'
```

Generates

```xquery
TODO
```

Returns

| AVG(temp) |
| --- |
| 10 |

```sql
SELECT * from "triples.<http://marklogic.com/semantics/Person>"
WHERE "<http://marklogic.com/semantics/Person/name>" = "Adam Fowler"
```

Generates

```sparql
sem:sparql("
  SELECT ?subject ?predicate ?object GRAPH ?graph WHERE {
    ?subject a <http://marklogic.com/semantics/Person> .
    ?subject <http://marklogic.com/semantics/Person/name> "Adam Fowler" .
    ?subject ?predicate ?object .
  }
")
```

Returns

| uri | subject | graph | <http://marklogic.com/semantics/Person/name> | etc |
| --- | --- | --- | --- |
| /triples/123456 | <http://marklogic.com/semantics/Person#AdamFowler> | default | Adam Fowler | etc |


```sql
SELECT subject,<http://marklogic.com/semantics/Person/age> from "triples.<http://marklogic.com/semantics/Person>"
WHERE "<http://marklogic.com/semantics/Person/name>" = "Adam Fowler"
```

Generates

```sparql
sem:sparql("
  SELECT ?subject ?predicate ?object GRAPH ?graph WHERE {
    ?subject a <http://marklogic.com/semantics/Person> .
    ?subject <http://marklogic.com/semantics/Person/name> "Adam Fowler" .
    ?subject ?predicate ?object .
    FILTER (?predicate = (<http://marklogic.com/semantics/Person/age>) ) .
  }
")
```

Returns

| uri | subject | graph | <http://marklogic.com/semantics/Person/age> |
| --- | --- | --- | --- |
| /triples/123456 | <http://marklogic.com/semantics/Person#AdamFowler> | default | 33 |

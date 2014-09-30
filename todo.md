# TODO items

## Basic functionality

- Provide support for ANSI SQL against pure MarkLogic content databases
 - TEST general parser/producer framework
 - ansi-sql parser
  - ENBF for ANSI SQL
  - XQuery AST parser in to XML target format
  - XSLT for AST to target query format, if applicable (to simplify output XML used in SQL library)
- Support for SELECT only (query performing, NOT parsing requirements)
 - Document content
  - Support for server registered namespaces (admin api path range indexes)
  - TEST element value equals queries
   - TEST SELECT * FROM temperatures WHERE city='Derby'
   - TEST SELECT fieldlist FROM temperatures WHERE city='Derby'
  - range queries
   - SELECT DISTINCT(city) FROM temperatures WHERE temp >= 20
 - Triple content
  - SELECT * from "triples.<http://marklogic.com/semantics/Person>" WHERE "<http://marklogic.com/semantics/Person/name>" = "Adam Fowler"
  - SELECT subject,<http://marklogic.com/semantics/Person/age> from "triples.<http://marklogic.com/semantics/Person>" WHERE "<http://marklogic.com/semantics/Person/name>" = "Adam Fowler"
- Return results in standard Terminal like SQL response format
 - TEST CSV return format
 - TEST pipe delimited cli format
 - TEST XML map format
 - TEST JSON format

## Advanced features

- Advanced queries
  - aggregation range queries
   - SELECT AVG(temp),city FROM temperatures WHERE month='Jun' GROUP BY city
- Custom query types
 - MarkLogic brand of SQL, if applicable
- Allow results to be returned in a number of sensible formats
 - Are there any others???
- Support the ANSI Information Schema for discovery of data in MarkLogic
- Support for specifying database in REST API http headers - version 8 of MarkLogic with superport support

## Crazy features

- Cross document joins
- Support document inserts
- Cross document/triple boundary joins, supporting owl:sameAs and SKOS equivalent terms for doc values vs triple values

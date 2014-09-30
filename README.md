# MarkLogic SQL over HTTP (mlsqlhttp)

This library aims to provide a similar developer experience as Microsoft DocumentDB's SQL over HTTP support.

Rather than using the xdmp:sql implementation within MarkLogic, this library acts directly over range indexes, the
universal index, triples and lexicons.

This means you do not need to set up an ODBC view or ODBC connection to perform SQL against MarkLogic held data.

The aims of the project are:-

- Provide familiar SQL access to MarkLogic data
- Support all types of data held in MarkLogic (documents and triples)
- Act as a basis for database connection technologies (E.g. JDBC type 3 drivers)

Initial features include:-

- Provide support for ANSI SQL against pure MarkLogic content databases
- Support for SELECT only
- Return results in standard Terminal like SQL response format

Later features include:-

- Allow results to be returned in a number of sensible formats
- Support the ANSI Information Schema for discovery of data in MarkLogic

Crazy future potential features that may suck in performance include:-

- Cross document joins
- Support document inserts

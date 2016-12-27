# mongoose-jsonld

[![Build Status](https://travis-ci.org/infolis/mongoose-jsonld.svg?branch=master)](https://travis-ci.org/infolis/mongoose-jsonld)

mongoose-jsonld allows you to augment the schemas for the
[Mongoose](http://mongoosejs.com/) object-document mapper with a
[JSON-LD](http://json-ld.org/) context. With this additional information,
Mongoose documents and schemas can be converted to and imported from
semantically rich JSON-LD documents or RDF graphs with ease. Since
mongoose-jsonld is just a thin layer atop of Mongoose, developers can
concentrate on getting Mongoose schema design and performance right for
internal use and get JSON-LD/RDF support for interfaces.

## Terminology

* MongoDB is a document-oriented database
  * **Documents** are JSON objects with an identifier
  * A **Collection** hold documents

* Mongoose is an object-document mapper for MongoDB in Node.js
  * **Schemas** define structure and constraints of documents 
  * **Models** provide access to collections, model instances represent documents

* JSON-LD defines a modelling and processing framework for JSON objects. The "LD" part happens mostly in a JSON object's `@context` property
  * maps property names to URI
  * describe, using vocabularies like Dublin Core, schema.org, the "meaning" of the object and its components

## Example

The basic idea is to add `@context` to your schema.

Suppose you have a minimal Mongoose schema:

```yaml
  surname:
    type: "String"
    required: true
  given:
    type: "String"
```

With `@context` it might look like this:

```yaml
  @context:
    @id: "foaf:Person"
  surname:
    @context:
      @id: "foaf:surname"
    type: "String"
    required: true
  given:
    @context:
      @id: "foaf:givenName"
    type: "String"
```

The added meaning is:

* Every document in the `Person` collection represents one `foaf:Person`
* The `surname` and `given` properties have the meaning of `foaf:surname` and `foaf:givenName`, resp.

We can go one step further and define the whole data model from a single schema/JSON-LD document:

```yaml
  @ns:
    dc: "http://purl.org/dc/elements/1.1"
    schema: "http://schema.org/"
    owl: "http://www.w3.org/2002/07/owl#"
  @context:
    @id: 'http://example.org/schema.json'
    dc:description: 'My fancy Mongoose schema'
    dc:date: '2017-01-01'
  Person
    @context:
      @id: "foaf:Person"
      owl:sameAs:
        @id: 'schema:Person'
    surname:
      @context:
        @id: "foaf:surname"
      type: "String"
      required: true
    given:
      @context:
        @id: "foaf:givenName"
      type: "String"
```

* `@ns` defines namespaces for CURIE-abbreviated URI e.g. for property names
* Top-level `@context` describes the whole data model
* All non-`@`-prefixed top-level keys describe collections/classes
* Person is defined to be the `owl:sameAs` a `schema:Person`

Using this information, mongoose-jsonlod can transform an instance of `Person`
(`{_id: '123', surname: 'Doe', given: 'John'}`) to JSON-LD and parse it from JSON-LD

If you host your
data at `http://example.org/api` and your RDF data model at `http://example.org/schema`:

```json
{
  "@context": {
    "schema": "http://schema.org/",
    "foaf": "http://xmlns.com/foaf/0.1/",
    "myprefix": "http://example.org/schema/"
  },
  "@id": "http://example.org/api/person/123",
  "@type": "foaf:Person",
  "myprefix:surname": "Doe",
  "myprefix:given": "John"
}
```

Since it supports some common RDF properties like `owl:sameAs`, mongoose-jsonld
would also be able to parse into the same document this slightly different description:

```turtle
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix myprefix: <http://example.org/schema/> .

<http://example.org/api/person/123>
    a <http://schema.org/Person> ;
    myprefix:surname "John" ;
    foaf:givenName "John" .
```

You can also generate a full ontology from the schema definitions, dump your
database to N-Quads and there are settings to accomodate different views on the
data, e.g. when to use the internal URI, when to use `owl:sameAs` URI, how to
handle sequential data etc.

## State of the project

[We](https://github.com/infolis) were heavily using this in the late and great
[InFoLiS](https://infolis.github.io) project. I'm confident that the general approach
is excellent if you are proficient with document databases and want the interop of JSON-LD/RDF without the pains of developing with a truly RDF-based data model.

The implementation grew out of a prototype and leaves a lot of room for
improvement. There's also a primitive Linked Data Fragments implementation in
here, handlers for RESTful and schema web server middleware, a transformation
to use the data model description for Swagger API user interface, validation
routines, custom types and lots and lots of hacks.

## See also

* [tson](https://github.com/infolis/tson)
* [express-jsonld](https://github.com/infolis/express-jsonld)

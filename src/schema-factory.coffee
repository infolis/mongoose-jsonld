Merge = require 'merge'
{Schema} = require 'mongoose'
CommonContexts = require 'jsonld-common-contexts'
Validators = require './validators'
TypeMap = require './typemap'
JsonldRapper = require 'jsonld-rapper'

atIdSchema = {
	'@id': {
		'type': "String"
	}
}

module.exports = class JsonldSchemaFactory

	constructor : (opts = {}) ->
		opts or= {}
		@[k] = v for k,v of opts

		@expandContexts or= ['prefix.cc']
		@curie          or= CommonContexts.withContext(@expandContexts)
		@typeMap        or= Merge(TypeMap, opts.typemap)
		@validators     or= Merge(Validators, opts.validators)
		@baseURI        or= 'http://EXAMPLE.ORG'
		@apiPrefix      or= '/api/v1'
		@schemaPrefix   or= "/schema"
		@jsonldRapper or= new JsonldRapper(
			# baseURI: "#{@baseURI}#{@schemaPrefix}/"
			baseURI: "_-_o_-_"
			expandContext: @curie.namespaces('jsonld')
		)

		@uriForClass or= (short) ->
			return "#{@baseURI}#{@schemaPrefix}/#{short}"

		@uriForInstance or= (doc) ->
			apiBase = "#{@baseURI}#{@apiPrefix}"
			collectionName = doc.constructor.collection.name
			id = doc._id
			return "#{apiBase}/#{collectionName}/#{id}"

	_lcfirst : (str) ->
		str.substr(0,1).toLowerCase() + str.substr(1)

	createSchema : (className, schemaDef, mongooseOptions) ->
		mongooseOptions or= {}
		mongooseOptions['jsonldFactory'] = @

		# JSON-LD infos about the class
		classUri = @curie.shorten @uriForClass(className)
		schemaContext = {
			'@id': classUri
		}
		for ctxPropname, ctxPropDef of schemaDef['@context']
			schemaContext[ctxPropname] = ctxPropDef
		schemaContext['rdf:type'] or= [{'@id': 'owl:Thing'}]

		# Remove @context from the schema definition and move it to the schema options
		delete schemaDef['@context']
		mongooseOptions['@context'] = schemaContext

		# JSON-LD info about properties
		for propName, propDef of schemaDef

			# handle validate functions
			if propDef['validate'] and typeof propDef['validate'] is 'string'
				validateFn = @validators[propDef['validate']]
				if not validateFn
					throw new Error("No function handling #{propDef['validate']}")
				else
					propDef['validate'] = validateFn

			# handle dbrefs
			if propDef['type'] and Array.isArray(propDef['type'])
				typeDef = propDef['type'][0]
				if typeDef and typeDef['type'] and typeof typeDef['type'] is 'string'
					typeDef['type'] = @typemap[typeDef['type']]

			# handling flat types
			else if propDef['type'] and propDef['type'] and typeof propDef['type'] is 'string'
				propDef['type'] = @typemap[propDef['type']]

			# handle property @context
			propDef['@context'] or= {}
			if typeof propDef['@context'] is 'object'
				pc = {}

				# Canonicalize prefixed names
				for x,y of propDef['@context']
					pc[@curie.shorten @curie.expand x] = @curie.shorten @curie.expand y

				# rdf:type rdfs:Property
				pc['rdf:type'] or= []
				if typeof pc['rdf:type'] is 'string'
					pc['rdf:type'] = [pc['rdf:type']]
				pc['rdf:type'].push {'@id': 'rdfs:Property'}

				# enum values -> owl:oneOf
				enumValues = propDef.enum
				if enumValues and enumValues.length
					pc['rdfs:range'] = {
						'owl:oneOf': enumValues
						'@type': 'xsd:string'
					}

				# schema:domainIncludes (rdfs:domain)
				pc['schema:domainIncludes'] or= []
				pc['schema:domainIncludes'].push {'@id': classUri}

				propDef['@context'] = pc
			else 
				throw new Error('UNHANDLED @context being a string')

		schema = new Schema(schemaDef, mongooseOptions)
		schema.plugin(@createPlugin())
		return schema

	listAssertions: (doc, opts) ->
		factory = doc.schema.options.jsonldFactory
		opts = Merge @opts, opts

		obj = doc.toObject()
		actualFields = Object.keys(obj)

		# Set the @id to a dereferenceable URI
		obj['@id'] = factory.uriForInstance(doc)

		# Delete '_id' unless explicitly kept
		unless opts.keep_id
			delete obj._id

		# TODO is this the right behavior
		obj['@context'] = {}
		# obj['@context'] = Merge(opts.context, obj['@context'])
		# obj['@context'] = 'http://prefix.cc/context'

		schemaContext = doc.schema.options['@context']
		if schemaContext
			obj['@type'] = schemaContext['@id']
			obj['@context'][obj['@type']] = schemaContext

		# Walk the schema path definitions, adding their @context under their
		# path into the context for the schema
		for schemaPathName in actualFields
			schemaPathDef = doc.schema.paths[schemaPathName]
			# skip internal fields
			continue if /^_/.test schemaPathName
			propContext = schemaPathDef.options?['@context']
			continue unless propContext
			obj['@context'][schemaPathName] = propContext
		return obj

	listDescription: (model, opts) ->
		onto = []

		# Class def
		onto.push model.schema.options['@context']

		# Properties def
		for schemaPathName, schemaPathDef of model.schema.paths
			# skip internal fields
			continue if /^_/.test schemaPathName
			propCtx = schemaPathDef.options?['@context']
			continue unless propCtx
			propCtx['@id'] = @curie.shorten @uriForClass(schemaPathName)
			propCtx['@type'] = ['rdfs:Property']
			onto.push propCtx

		return onto

	_convert : (doc, opts, cb) ->
		if typeof opts == 'function' then [cb, opts] = [opts, {}]
		if not opts or not (opts['to'] or opts['profile'])
			return cb null, doc
		else if opts['profile']
			opts['to'] = 'jsonld'
		return @jsonldRapper.convert doc, 'jsonld', opts['to'], opts, cb

	createPlugin: (schema, opts) ->
		factory = @
		opts or= {}
		opts = Merge(@opts, opts)
		return (schema) ->

			# Every model can have an '@id' field
			schema.add(atIdSchema)

			# Allow export of the Linked Data description of the schema
			schema.methods.jsonldABox = (innerOpts, cb) ->
				if typeof innerOpts == 'function' then [cb, innerOpts] = [innerOpts, {}]
				doc = @
				innerOpts = Merge(opts, innerOpts)
				return factory._convert factory.listAssertions(doc, innerOpts, cb), innerOpts, cb

			schema.statics.jsonldTBox = (innerOpts, cb) ->
				if typeof innerOpts == 'function' then [cb, innerOpts] = [innerOpts, {}]
				model = @
				# console.log model.schema.options
				innerOpts = Merge(opts, innerOpts)
				return factory._convert factory.listDescription(model, innerOpts, cb), innerOpts, cb




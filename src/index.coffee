Merge = require 'merge'
JsonLD = require 'jsonld'
JsonLD2RDF = require 'jsonld-rapper'

idSchema = {
	'@id': {
		'type': "String"
	}
}

# maps concise names to paths to be required
predefinedContexts = {
	'prefix.cc': './contexts/prefix.cc'
	'rdfa11': './contexts/rdfa11'
	'basic': './contexts/basic'
}

loadContext = (optsOrString) ->
	# If this is a string but not a URL
	if typeof ctx is 'string' 
		if ctx.indexOf('/') == -1
			if not predefinedContexts[ctx]
				throw new Error "No such predefined context: #{ctx}"
			contextJson = require(predefinedContexts[ctx])
			ctx = contextJson['@context']
		else
			# TODO handle URLs somehow -- dereference?
	return ctx

# TODO remove unused prefixes
# removeUnused = (doc) ->

module.exports = class MongooseJsonLD

	constructor: (opts) ->
		m2j = @
		@opts = {}
		@opts[k] = v for k,v of opts
		@opts.profile or= 'compact'
		@opts.apiBase or= 'http://EXAMPLE.ORG/CHANGE-ME/API'
		@opts.schemaBase or= 'http://EXAMPLE.ORG/CHANGE-ME/SCHEMA'
		@opts.expandContext or= 'basic'
		# Load the context up
		@opts.expandContext = loadContext(opts.expandContext)
		@opts.j2r = new JsonLD2RDF(
			expandContext: @opts.expandContext
		)

	urlForInstance: (doc) ->
		apiBase = @apiBase
		collectionName = doc.constructor.collection.name
		id = doc._id
		return "#{apiBase}/#{collectionName}/#{id}"

	urlForClass: (short) ->
		return "#{@opts.schemaBase}/#{short}"

	listAssertions: (doc, opts, cb) ->
		opts = Merge @opts, opts
		obj = doc.toObject()

		# Set the @id to a dereferenceable URI
		obj['@id'] = @urlForInstance(doc)

		# Delete '_id' unless explicitly kept
		unless opts.keep_id
			delete obj._id

		# # TODO is this the right behavior
		obj['@context'] = {}
		# obj['@context'] = Merge(opts.context, obj['@context'])
		# obj['@context'] = 'http://prefix.cc/context'

		for schemaPathName, schemaPathDef of doc.schema.paths
			# skip internal fields
			continue if /^_/.test schemaPathName
			continue if not schemaPathDef.options?['@context']
			obj['@context'][schemaPathName] = schemaPathDef.options['@context']
			# console.log schemaPathDef
			enumValues = schemaPathDef.enum?().enumValues
			if enumValues and enumValues.length
				obj['@context'][schemaPathName]['rdfs:range'] = {
					'owl:oneOf': enumValues
					'@type': 'rdfs:Datatype'
				}
		# TODO J2Rdf
		cb null, obj


	listDescription: (model, opts, cb) ->
		onto = []

		# Class def
		classDef = model.schema.options['@context'] || {}
		console.log classDef
		classDef['@id'] = @urlForClass(model.modelName)
		onto.push classDef

		# Properties def
		for schemaPathName, schemaPathDef of model.schema.paths
			# skip internal fields
			continue if /^_/.test schemaPathName
			continue if /^@context/.test schemaPathName
			continue if not schemaPathDef.options?['@context']
			propertyDef = schemaPathDef.options['@context']
			if not propertyDef['@id']
				propertyDef['@id'] = @urlForClass(schemaPathName)
			propertyDef['schema:domainIncludes'] = classDef['@id']
			propertyDef['@type'] = ['rdfs:Property']
			onto.push propertyDef

		# console.log onto
		# TODO J2Rdf
		cb null, onto

	createPlugin: (schema, opts) ->
		mongooseJsonLD = @
		opts or= {}
		opts = Merge(@opts, opts)
		return (schema) ->

			# Set the method for export IDs
			schema.methods.urlForInstance = opts.urlForInstance

			# Every model can have an '@id' field
			schema.add(idSchema)

			# Allow export of the Linked Data description of the schema
			schema.methods.jsonldABox = (innerOpts, cb) ->
				if typeof innerOpts == 'function' then [cb, innerOpts] = [innerOpts, {}]
				doc = @
				innerOpts = Merge(opts, innerOpts)
				return mongooseJsonLD.listAssertions(doc, innerOpts, cb)

			schema.statics.jsonldTBox = (innerOpts, cb) ->
				if typeof innerOpts == 'function' then [cb, innerOpts] = [innerOpts, {}]
				model = @
				innerOpts = Merge(opts, innerOpts)
				return mongooseJsonLD.listDescription(model, innerOpts, cb)

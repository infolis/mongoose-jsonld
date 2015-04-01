Merge          = require 'merge'
Mongoose       = require 'mongoose'
CommonContexts = require 'jsonld-common-contexts'
JsonldRapper   = require 'jsonld-rapper'
ExpressJSONLD  = require 'express-jsonld'

Validators     = require './validators'
TypeMap        = require './typemap'

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
		@expressJsonldMiddleware = new ExpressJSONLD(@).getMiddleware()

		@uriForClass or= (short) ->
			return "#{@baseURI}#{@schemaPrefix}/#{short}"

		@uriForInstance or= (doc) ->
			return "#{@baseURI}#{@apiPrefix}/#{doc.constructor.collection.name}/#{doc._id}"

	_lcfirst : (str) ->
		str.substr(0,1).toLowerCase() + str.substr(1)

	_listAssertions: (doc, opts) ->
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

	_listDescription: (model, opts) ->
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
				return factory._convert factory._listAssertions(doc, innerOpts, cb), innerOpts, cb

			schema.statics.jsonldTBox = (innerOpts, cb) ->
				if typeof innerOpts == 'function' then [cb, innerOpts] = [innerOpts, {}]
				model = @
				# console.log model.schema.options
				innerOpts = Merge(opts, innerOpts)
				return factory._convert factory._listDescription(model, innerOpts, cb), innerOpts, cb

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

		schema = new Mongoose.Schema(schemaDef, mongooseOptions)
		schema.plugin(@createPlugin())
		return schema

	_castId : (model, res, toParse) ->
		id = null
		idType = model.schema.paths['_id'].instance
		try
			# console.log idType
			switch idType
				when "ObjectID"
					if Mongoose.Types.ObjectId.isValid(toParse)
						id = Mongoose.Types.ObjectId(toParse)
				else
					id = toParse
		catch e
			console.log "Error happened when trying to cast '#{toParse}' to #{idType}"
			console.log e
			res.status 404
		return id

	_conneg : (req, res, next) ->
		self = @
		if not req.mongooseDoc
			res.end()
		else if not req.headers.accept or req.headers.accept in ['*/*', 'application/json']
			if Array.isArray(req.mongooseDoc)
				res.send req.mongooseDoc.map (el) -> el.toJSON()
			else
				res.send req.mongooseDoc.toJSON()
		else
			if Array.isArray(req.mongooseDoc)
				Async.map req.mongooseDoc, (doc, eachDoc) ->
					doc.jsonldABox eachDoc
				, (err, result) =>
					req.jsonld = result
					self.expressJsonldMiddleware(req, res, next)
			else
				req.mongooseDoc.jsonldABox req.mongooseDoc, (err, jsonld) ->
					req.jsonld = jsonld
					self.expressJsonldMiddleware(req, res, next)

	_GET_Resource : (model, req, res, next) ->
		console.log "GET #{model.modelName}##{req.params.id} "
		id = @_castId(model, res, req.params.id)
		if not id
			res.status 404
			return next()

		model.findOne {_id: req.params.id}, (err, doc) ->
			if err
				res.status 500
				return next new Error(err)
			if not doc
				res.status 404
			else
				res.status 200
				req.mongooseDoc = doc
			return next()

	_GET_Collection : (model, req, res, next) ->
		console.log "GET every #{model.modelName}"
		model.find {}, (err, docs) ->
			if err
				res.status 500
				return next new Error(err)
			res.status = 200
			req.mongooseDoc = docs
			next()

	_DELETE_Collection: (model, req, res, next) ->
		console.log "DELETE all #{model.modelName}"
		model.remove {}, (err, removed) ->
			if err
				res.status 500
				return next new Error(err)
			res.status 200
			console.log "Removed #{removed} documents"
			next()

	_DELETE_Resource : (model, req, res, next) ->
		console.log "DELETE #{model.modelName}##{req.params.id}"
		id = @_castId(model, res, req.params.id)
		if not id
			res.status 404
			return next()
		input = req.body
		model.remove {_id: id}, (err, nrRemoved) ->
			if err
				res.status 400
				return next new Error(err)
			if nrRemoved == 0
				res.status 404
			else
				res.status 201
			next()

	_POST_Resource: (model, req, res, next) ->
		self = @
		# console.log req.body
		doc = new model(req.body)
		console.log "POST new '#{model.modelName}' resource: #{doc.toJSON()}"
		doc.save (err, newDoc) ->
			if err
				res.status 500
				return next new Error(err)
			else
				res.status 201
				res.header "Location", "/api/#{model.collection.name}/#{newDoc._id}" # XXX TODO
				req.mongooseDoc = newDoc
				next()

	_PUT_Resource : (model, req, res, next) ->
		console.log "PUT #{model.modelName}##{req.params.id}"
		input = req.body
		id = @_castId(model, res, req.params.id)
		if not id
			res.status 404
			return next()
		delete input._id
		model.update {_id: id}, input, {upsert: true}, (err, nrUpdated) ->
			if err
				res.status 400
				return next new Error(err)
			if nrUpdated == 0
				res.status 400
				return next new Error("No updates were made?!")
			else
				res.status 201
				res.end()

	injectRestfulHandlers: (app, model, nextMiddleware) ->
		if not app
			throw Error("No app given")
		if not nextMiddleware
			nextMiddleware = @_conneg.bind(@)

		self = @
		# basePath = "#{@apiPrefix}/#{model.collection.name}"
		modelName = model.modelName
		_lcfirst = (str) -> str.substr(0,1).toLowerCase() + str.substr(1)
		basePath = "#{@apiPrefix}/#{_lcfirst(model.modelName)}"

		api = {}
		# GET /api/somethings/:id     => get a 'something' with :id
		api["GET #{basePath}/:id"]     = @_GET_Resource
		# GET /api/somethings         => List all somethings
		api["GET #{basePath}/?"]       = @_GET_Collection
		# POST /api/somethings        => create new something
		api["POST #{basePath}/?"]      = @_POST_Resource
		# PUT /api/somethings/:id     => create/replace something with :id
		api["PUT #{basePath}/:id"]     = @_PUT_Resource
		# DELETE /api/somethings/!    => delete all somethings [XXX DANGER ZONE]
		api["DELETE #{basePath}/!!"]   = @_DELETE_Collection
		# DELETE /api/somethings/:id  => delete something with :id
		api["DELETE #{basePath}/:id"]  = @_DELETE_Resource

		console.log "Registering REST Handlers on basePath '#{basePath}'"
		for methodAndPath, handle of api
			do (methodAndPath, handle, nextMiddleware) ->
				expressMethod = methodAndPath.substr(0, methodAndPath.indexOf(' ')).toLowerCase()
				path = methodAndPath.substr(methodAndPath.indexOf(' ') + 1)
				console.log "#{expressMethod} '#{path}'"
				app[expressMethod](
					path
					(req, res, next) -> handle.apply(self, [model, req, res, next])
					(req, res, next) -> nextMiddleware(req, res, next)
				)

	injectSchemaHandlers : (app, model, nextMiddleware) ->
		if not nextMiddleware
			nextMiddleware = @_conneg.bind(@)

		basePath = @schemaPrefix

		self = @
		do (self) =>
			path = "#{@schemaPrefix}/#{model.modelName}"
			console.log "Binding schema handler #{path}"
			app.get path,
				(req, res) ->
					req.jsonld = model.schema.options['@context']
					if not req.headers.accept or req.headers.accept in ['*/*', 'application/json']
						res.send JSON.stringify(req.jsonld, null, 2)
					else
						self.expressJsonldMiddleware(req, res)



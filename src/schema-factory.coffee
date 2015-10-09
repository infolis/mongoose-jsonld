Async = require 'async'
Merge    = require 'merge'
Uuid     = require 'node-uuid'

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

INTERNAL_FIELD_REGEX=/^[\$_]/

module.exports = class MongooseJSONLD

	constructor : (opts = {}) ->
		opts or= {}
		@[k] = v for k,v of opts

		if not @mongoose
			throw 'Must pass mongoose'

		opts.expandContexts or= ['prefix.cc']
		@curie        or= CommonContexts.withContext(opts.expandContexts)
		@typeMap      = Merge(TypeMap, opts.typemap)
		@validators   = Merge(Validators, opts.validators)
		@baseURI      or= 'http://EXAMPLE.ORG'
		@apiPrefix    or= '/api/v1'
		@schemaPrefix or= "/schema"
		@jsonldRapper or= new JsonldRapper(
			# baseURI: "#{@baseURI}#{@schemaPrefix}/"
			baseURI: "(ツ)"
			curie: @curie
		)
		expressJSONLD = new ExpressJSONLD(
			jsonldRapper: @jsonldRapper
		)
		@expressJsonldMiddleware = expressJSONLD.getMiddleware()

		@uriForClass or= (short) ->
			return "#{@baseURI}#{@schemaPrefix}/#{short}"

		@uriForInstance or= (doc) ->
			return "#{@baseURI}#{@apiPrefix}/#{@_lcfirst doc.constructor.modelName}/#{doc._id}"

	_lcfirst : (str) ->
		str.substr(0,1).toLowerCase() + str.substr(1)

	_listAssertions: (doc, opts, depth = 0) ->
		factory = doc.schema.options.jsonldFactory
		opts = Merge @opts, opts
		# opts.keep_id or= true
		ret = {}

		flatDoc = doc.toJSON()

		# Set the @id to a dereferenceable URI
		ret['@id'] = factory.uriForInstance(doc)

		# TODO is this the right behavior
		ret['@context'] or= {}

		schemaContext = doc.schema.options['@context']
		if schemaContext
			ret['@type'] = schemaContext['@id']
			ret['@context'][ret['@type']] = schemaContext

		# Walk the schema path definitions, adding their @context under their
		# path into the context for the schema
		for schemaPathName of doc.toJSON()
			schemaPathDef = doc.schema.paths[schemaPathName]
			propDef = doc[schemaPathName]

			# skip internal fields
			continue if INTERNAL_FIELD_REGEX.test schemaPathName
			if not schemaPathDef
				console.log schemaPathName
				continue

			# Add property data to the context
			propContext = schemaPathDef.options?['@context']
			if propContext
				ret['@context'][schemaPathName] = propContext

			schemaPathOptions = schemaPathDef.options
			if @_isJoinSingle schemaPathOptions
				# console.log "#{schemaPathName}: _isJoinSingle"
				# console.log propDef
				# XXX recursive
				ret[schemaPathName] = factory._listAssertions(propDef, opts)
			else if @_isJoinMulti schemaPathOptions
				# console.log "#{schemaPathName}: _isJoinMulti"
				ret[schemaPathName] = []
				for subDoc in propDef
					# XXX recursive
					ret[schemaPathName].push factory._listAssertions(subDoc, opts, depth + 1)
			else
				# console.log "#{schemaPathName}: standard: '#{flatDoc[schemaPathName]}'"
				ret[schemaPathName] = flatDoc[schemaPathName]

		# Delete '_id' unless explicitly kept
		# if opts.keep_id
		#     ret._id = doc._id

		return ret

	_createDocumentFromObject : (model, obj) ->
		for schemaPathName of obj
			schemaPathDef = model.schema.paths[schemaPathName]
			schemaPathOptions = schemaPathDef.options
			if @_isJoinSingle schemaPathOptions
				obj[schemaPathName] = @_lastUriSegment(obj[schemaPathName])
			else if @_isJoinMulti schemaPathOptions
				for i in [0 ... obj[schemaPathName].length]
					obj[schemaPathName][i] = @_lastUriSegment(obj[schemaPathName][i])
		return new model(obj)

	_findOneAndPopulate : (model, searchDoc, cb) ->
		builder = model.findOne(searchDoc)
		for schemaPathName, schemaPathDef of model.schema.paths
			schemaPathType = schemaPathDef.options
			if @_isJoinSingle(schemaPathType) or @_isJoinMulti(schemaPathType)
				builder.populate(schemaPathName)
		return builder.exec cb

	_isJoinMulti : (def) ->
		typeof(def) is 'object' and
		def.type and
		Array.isArray(def.type) and
		def.type[0] and
		typeof def.type[0] is 'object' and
		def.type[0].ref and
		def.type[0].type

	_isJoinSingle : (def) ->
		return typeof(def) is 'object' and
			not(Array.isArray def) and
			def.ref and
			def.type


	_listDescription: (model, opts) ->
		onto = []

		# Class def
		onto.push model.schema.options['@context']

		# Properties def
		for schemaPathName, schemaPathDef of model.schema.paths
			# skip internal fields
			continue if INTERNAL_FIELD_REGEX.test schemaPathName
			propCtx = schemaPathDef.options?['@context']
			continue unless propCtx
			propCtx['@id'] = @curie.shorten @uriForClass(schemaPathName)
			# propCtx['@type'] = 'rdfs:Property'
			onto.push propCtx

		return onto

	_lastUriSegment : (uri) ->
		return uri.substr(uri.lastIndexOf('/') + 1)

	# _isDBRef : (data) ->
	#     if not def
	#         return false
	#     else if Array.isArray(def)



	_convert : (doc, opts, cb) ->
		if typeof opts == 'function' then [cb, opts] = [opts, {}]
		if not opts or not (opts['to'] or opts['profile'])
			return cb null, doc
		else if not opts['to'] and opts['profile']
			opts['to'] = 'jsonld'
		return @jsonldRapper.convert doc, 'jsonld', opts['to'], opts, cb

	createPlugin: (schema, opts) ->
		factory = this
		opts or= {}
		opts = Merge(@opts, opts)
		return (schema) ->

			# Every model can have an '@id' field
			schema.add(atIdSchema)

			# We enforce UUIDs for all the things
			schema.add '_id' : {
				type: 'String'
				validate: factory.validators.UUID
				# required: yes
			}
			schema.pre 'save', (next) ->
				doc = this
				if doc.isNew and not doc._id
					doc.setValue '_id', Uuid.v1()
				next()

			# Allow export of the Linked Data description of the schema
			schema.methods.jsonldABox = (innerOpts, cb) ->
				if typeof innerOpts == 'function' then [cb, innerOpts] = [innerOpts, {}]
				doc = this
				innerOpts = Merge(opts, innerOpts)
				if cb
					return factory._convert factory._listAssertions(doc, innerOpts), innerOpts, cb
				else
					return factory._listAssertions(doc, innerOpts)

			schema.methods.uri = () ->
				return factory.uriForInstance(this)

			schema.statics.jsonldTBox = (innerOpts, cb) ->
				if typeof innerOpts == 'function' then [cb, innerOpts] = [innerOpts, {}]
				model = this
				innerOpts = Merge(opts, innerOpts)
				if cb
					return factory._convert factory._listDescription(model, innerOpts), innerOpts, cb
				else
					return factory._listDescription(model, innerOpts)

			schema.statics.findOneAndPopulate = (searchDoc, cb) ->
				factory._findOneAndPopulate(this, searchDoc, cb)

			schema.statics.fromJSON = (obj, cb) ->
				factory._createDocumentFromObject(this, obj, cb)

	createModel : (dbConnection, className, schemaDef, mongooseOptions) ->
		schema = @createSchema(className, schemaDef, mongooseOptions)
		dbConnection.model(className, schema)

	createSchema : (className, schemaDef, mongooseOptions) ->
		mongooseOptions or= {}
		mongooseOptions['jsonldFactory'] = this

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

			# handle dbrefs
			if propDef['type'] and Array.isArray(propDef['type'])
				typeDef = propDef['type'][0]
				if typeDef and typeDef['type'] and typeof typeDef['type'] is 'string'
					typeDef['type'] = @typeMap[typeDef['type']]

			# handle validate functions
			if propDef['validate'] and typeof propDef['validate'] is 'string'
				validateFn = @validators[propDef['validate']]
				if not validateFn
					throw new Error("No function handling #{propDef.validate}")
				else
					propDef['validate'] = validateFn

			# handling flat types
			if propDef['type'] and propDef['type'] and typeof propDef['type'] is 'string'
				propDef['type'] = @typeMap[propDef['type']]

			# handle required
			if not propDef.required
				propDef.required = no

			# handle property @context
			pc = propDef['@context'] || {}
			if typeof pc isnt 'object'
				throw new Error("UNHANDLED @context not being an object, but #{typeof pc}")

			# Canonicalize prefixed names
			for x,y of propDef['@context']
				if typeof y is 'string'
					pc[@curie.shorten @curie.expand x] = @curie.shorten @curie.expand y
				else
					pc[@curie.shorten @curie.expand x] = y

			# TODO this was wrong
			# # rdf:type rdfs:Property
			# pc['@type'] or= []
			# if typeof pc['@type'] is 'string'
			#     pc['@type'] = [pc['@type']]
			# pc['@type'].push {'@id': 'rdfs:Property'}

			# enum values -> owl:oneOf
			enumValues = propDef.enum
			if enumValues and enumValues.length
				pc['rdfs:range'] = {
					'owl:oneOf': enumValues
					'@type': 'xsd:string'
				}

			if not pc['rdfs:range']
				switch propDef.type
					when String, 'String'
						pc['rdfs:range'] = {'@id': 'xsd:string'}
					else
						# XXX do nothing
						null

			# schema:domainIncludes (rdfs:domain)
			pc['schema:domainIncludes'] or= []
			pc['schema:domainIncludes'].push {'@id': classUri}

			propDef['@context'] = pc

		schema = new @mongoose.Schema(schemaDef, mongooseOptions)
		schema.plugin(@createPlugin())
		return schema

	_castId : (model, res, toParse) ->
		id = null
		idType = model.schema.paths['_id'].instance
		try
			switch idType
				when "ObjectID"
					if @mongoose.Types.ObjectId.isValid(toParse)
						id = @mongoose.Types.ObjectId(toParse)
				else
					id = toParse
		catch e
			console.log "Error happened when trying to cast '#{toParse}' to #{idType}"
			console.log e
			res.status 404
		return id

	_conneg : (req, res, next) ->
		self = this
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
		searchDoc = {}
		for k, v of req.query
			searchDoc[k] = v
		model.find searchDoc, (err, docs) ->
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
		self = this
		doc = new model(req.body)
		console.log "POST new '#{model.modelName}' resource: #{JSON.stringify(doc.toJSON())}"

		doc.save (err, newDoc) ->
			if err or not newDoc
				res.status 400
				ret = new Error(err)
				ret.cause = err
				return next ret
			else
				res.status 201
				res.header 'Location', doc.uri()
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

		self = this
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
				# console.log "#{expressMethod} '#{path}'"
				app[expressMethod](
					path
					(req, res, next) -> handle.apply(self, [model, req, res, next])
					(req, res, next) -> nextMiddleware(req, res, next)
				)

	injectSchemaHandlers : (app, model, nextMiddleware) ->
		if not nextMiddleware
			nextMiddleware = @_conneg.bind(this)

		basePath = @schemaPrefix

		self = this
		do (self) =>
			path = "#{@schemaPrefix}/#{model.modelName}"
			console.log "Binding schema handler #{path}"
			app.get path, (req, res, next) ->
				# req.jsonld = model.schema.options['@context']
				req.jsonld = model.jsonldTBox()
				# console.log req.jsonld
				if not req.headers.accept or req.headers.accept in ['*/*', 'application/json']
					res.send JSON.stringify(req.jsonld, null, 2)
				else
					self.expressJsonldMiddleware(req, res, next)
			for propPath, propDef of model.schema.paths
				continue if INTERNAL_FIELD_REGEX.test propPath
				# console.log propPath
				do (propDef) =>
					app.get "#{@schemaPrefix}/#{propPath}", (req, res, next) ->
						req.jsonld = propDef.options['@context']
						if not req.headers.accept or req.headers.accept in ['*/*', 'application/json']
							res.send JSON.stringify(req.jsonld, null, 2)
						else
							self.expressJsonldMiddleware(req, res, next)


module.exports = class RestfulHandler

	constructor: (@apiPrefix) ->

	injectRestfulHandlers: (app, model, nextMiddleware) ->
		if not app
			throw Error("No app given")
		if not nextMiddleware
			nextMiddleware = @_conneg.bind(@)

		self = this
		# basePath = "#{@apiPrefix}/#{model.collection.name}"
		modelName = model.modelName
		basePath = "#{@apiPrefix}/#{StrUtils.lcfirst(model.modelName)}"

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
		searchDoc = {}
		if req.query.q
			for kvPair in req.query.q.split(',')
				[k,v] = kvPair.split(':')
				searchDoc[k] = v
			searchDoc[@_pathNameForPropertyUri model, k] = v
		console.log "GET every #{model.modelName} with #{JSON.stringify searchDoc}"
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

	_castId : (model, res, toParse) ->
		id = null
		idType = model.schema.paths['_id'].instance
		try
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


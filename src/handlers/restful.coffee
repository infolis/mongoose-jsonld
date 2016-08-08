Utils = require '../utils'
Base = require '../base'

log = require('../log')(module)

module.exports = class RestfulHandler extends Base

	inject: (app, done) ->
		nextMiddleware = @_conneg.bind(@)
		self = this
		for modelName, model of @models
			do (modelName, model) =>
				# basePath = "#{@apiPrefix}/#{model.collection.name}"
				modelName = model.modelName
				basePath = "#{@apiPrefix}/#{Utils.lcfirst(model.modelName)}"
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
				log.debug "Registering REST Handlers on basePath '#{basePath}'"
				for methodAndPath, handle of api
					do (methodAndPath, handle, nextMiddleware) =>
						expressMethod = methodAndPath.substr(0, methodAndPath.indexOf(' ')).toLowerCase()
						path = methodAndPath.substr(methodAndPath.indexOf(' ') + 1)
						log.debug "#{expressMethod} '#{path}'"
						app[expressMethod](
							path
							(req, res, next) -> handle.apply(self, [model, req, res, next])
							(req, res, next) -> nextMiddleware(req, res, next)
						)
		done() if done

	_GET_Resource : (model, req, res, next) ->
		id = @_castId(model, res, req.params.id)
		log.debug "GET #{model.modelName}##{id}"
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
		q = req.query.q
		max = req.query.max or 500
		if q
			searchDoc = '$and': []
			q = q.replace /,\s*$/, ''
			for kvPair in q.split(',')
				k = Utils.lastUriSegment(kvPair.substr(0, kvPair.indexOf(':')))
				v = kvPair.substr(kvPair.indexOf(':') + 1)
				log.debug k, v
				if v and typeof v is 'string' and v.indexOf('http://') == 0
					v = "#{Utils.lastUriSegment(v)}$"
				log.debug k, v
				searchDoc.$and.push "#{k}" : { "$regex": v }
		log.debug "GET every #{model.modelName} with #{JSON.stringify searchDoc}"
		model.find(searchDoc).limit(max).exec (err, docs) ->
			if err
				log.error err
				res.status 500
				return next new Error(err)
			log.debug "Found #{docs.length} #{model.modelName}s"
			res.status 200
			req.mongooseDoc = docs
			next()

	_DELETE_Collection: (model, req, res, next) ->
		log.warn "DELETE all #{model.modelName}"
		model.remove {}, (err, removed) ->
			if err
				res.status 500
				return next new Error(err)
			res.status 200
			log.debug "Removed #{removed} documents"
			next()

	_DELETE_Resource : (model, req, res, next) ->
		log.warn "DELETE #{model.modelName}##{req.params.id}"
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
		log.debug "POST new '#{model.modelName}' resource: #{JSON.stringify(doc.toJSON())}"

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
		log.debug "PUT #{model.modelName}##{req.params.id}"
		input = req.body
		id = @_castId(model, res, req.params.id)
		if not id
			res.status 404
			return next()
		# delete input._id
		input._id = id
		model.findOne {_id: id}, (err, doc) ->
			if err
				res.status 400
				return next new Error(err)
			doc or= new model(input)
			doc.set(k,v) for k,v of input
			log.silly doc._id
			doc.save (err) ->
				if err
					res.status 400
					return next new Error(err)
				res.header 'Location', doc.uri()
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
			log.error "Error happened when trying to cast '#{toParse}' to #{idType}", e
			res.status 404
		return id

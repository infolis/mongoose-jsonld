Async          = require 'async'
CommonContexts = require 'jsonld-common-contexts'
JsonldRapper   = require 'jsonld-rapper/src'
ExpressJSONLD  = require 'express-jsonld'
Merge          = require 'merge'

Validators     = require './validators'
TypeMap        = require './typemap'
Utils          = require './utils'

module.exports  = class MongooseJsonldBase

	constructor: (opts) ->
		opts or= {}
		if not opts.mongoose
			throw "Must pass Mongoose DB Connection as 'mongoose'"
		@mongoose = opts.mongoose
		#
		# Populate this with the arguments passed to constructor
		#
		@[k] = v for k,v of opts
		@baseURI      or= 'http://EXAMPLE.ORG'
		@apiPrefix    or= '/api'
		@schemaPrefix or= "/schema"
		opts.expandContexts or= ['prefix.cc']
		@curie        or= CommonContexts.withContext(opts.expandContexts)
		@jsonldRapper or= new JsonldRapper(
			# baseURI: "#{@baseURI}#{@schemaPrefix}/"
			baseURI: "(ツ)"
			curie: @curie
		)
		@baseURI      or= 'http://EXAMPLE.ORG'
		@apiPrefix    or= '/api'
		@schemaPrefix or= "/schema"
		@typeMap      = Merge(TypeMap, opts.typemap)
		@validators   = Merge(Validators, opts.validators)
		@expressJsonldMiddleware = new ExpressJSONLD(jsonldRapper: @jsonldRapper).getMiddleware()
		@uriForClass or= (short) ->
			return "#{@baseURI}#{@schemaPrefix}/#{short}"
		@uriForInstance or= (doc) ->
			return "#{@baseURI}#{@apiPrefix}/#{Utils.lcfirst doc.constructor.modelName}/#{doc._id}"

	serialize : (doc, opts, cb) ->
		if typeof opts == 'function' then [cb, opts] = [opts, {}]
		if not opts or not (opts['to'] or opts['profile'])
			return cb null, doc
		else if not opts['to'] and opts['profile']
			opts['to'] = 'jsonld'
		return @jsonldRapper.convert doc, 'jsonld', opts['to'], opts, cb

	#
	# Basic JSON-LD middleware that handles arrays
	#
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

CommonContexts = require 'jsonld-common-contexts'
JsonldRapper   = require 'jsonld-rapper'
ExpressJSONLD  = require 'express-jsonld'
Merge          = require 'merge'
Validators     = require './validators'
TypeMap        = require './typemap'
{inspect}      = require 'util'

module.exports  = class Utils

	@INTERNAL_FIELD_REGEX: /^[\$_]/
	@CONTEXT_FIELD_REGEX: /^@context$/

	@lcfirst : (str) ->
		str.substr(0,1).toLowerCase() + str.substr(1)

	@lastUriSegment : (uri) ->
		return uri.substr(uri.lastIndexOf('/') + 1)

	@withoutContext : (def) ->
		out = {}
		for k, v of def
			if k.match(Utils.INTERNAL_FIELD_REGEX.match) or k.match(Utils.CONTEXT_FIELD_REGEX)
				continue
			out[k] = {}
			for kk, vv of v
				if k.match(Utils.INTERNAL_FIELD_REGEX.match) or k.match(Utils.CONTEXT_FIELD_REGEX)
					continue
				out[k][kk] = vv
		return out

	@isJoinMulti : (def) ->
		typeof(def) is 'object' and
		def.type and
		Array.isArray(def.type) and
		def.type[0] and
		typeof def.type[0] is 'object' and
		def.type[0].ref and
		def.type[0].type

	@isJoinSingle : (def) ->
		return typeof(def) is 'object' and
			not(Array.isArray def) and
			def.ref and
			def.type

	constructor: (opts) ->
		opts or= {}
		if not opts.mongoose
			throw "Must pass Mongoose DB Connection as 'mongoose'"

		@[k] = v for k,v of opts

		@jsonldRapper or= new JsonldRapper(
			# baseURI: "#{@baseURI}#{@schemaPrefix}/"
			baseURI: "(ツ)"
			curie: @curie
		)
		opts.expandContexts or= ['prefix.cc']
		@curie        or= CommonContexts.withContext(opts.expandContexts)
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

	_convert : (doc, opts, cb) ->
		if typeof opts == 'function' then [cb, opts] = [opts, {}]
		if not opts or not (opts['to'] or opts['profile'])
			return cb null, doc
		else if not opts['to'] and opts['profile']
			opts['to'] = 'jsonld'
		return @jsonldRapper.convert doc, 'jsonld', opts['to'], opts, cb

	dump: (obj) ->
		inspect obj, {
			depth: 1
			showHidden: false
			colors: true
		}

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

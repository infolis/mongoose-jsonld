Async   = require 'async'
Accepts = require 'accepts'
Utils   = require '../utils'
Base    = require '../base'

log = require('../log')(module)

HYDRA = "http://www.w3.org/ns/hydra/core#"
VOID = "http://rdfs.org/ns/void#"
RDF = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
RDF_TYPE = RDF + "type"

module.exports = class LdfHandlers extends Base

	constructor: ->
		super
		@apiBaseURI = "#{@baseURI}#{@apiPrefix}/"
		@schemaBaseURI = "#{@baseURI}#{@schemaPrefix}/"
		@ldfEndpoint = "#{@apiPrefix}/ldf"

	inject: (app, done) ->
		app.get @ldfEndpoint, (req, res, next) =>
			ldfQuery = req.query
			ldfQuery.limit     = parseInt(req.query.limit) or 100
			ldfQuery.offset    = parseInt(req.query.offset) or 0
			ldfQuery.subject   = req.query.subject
			ldfQuery.predicate = req.query.predicate
			ldfQuery.object    = req.query.object
			for pos in ['subject','predicate','object']
				if ldfQuery[pos] is ''
					delete ldfQuery[pos]
			tripleStream = []

			totalCount = 0
			metadataCallback = (metadata) ->
				totalCount += metadata.totalCount
			@handleLDFQuery ldfQuery, tripleStream, metadataCallback, (err) =>
				acceptable = Accepts(req).types()
				if acceptable.length == 0 or 'application/n3+json' in acceptable
					res.send tripleStream
				else
					@jsonldRapper.convert tripleStream, 'json3', 'jsonld', (err, converted) =>
						req.jsonld = converted
						res.locals.is_ldf = true
						res.locals[k] = v for k,v of ldfQuery
						@expressJsonldMiddleware(req, res, next)
		done()

	###
	# 
	# _handle_s
	# S: Construct query [Mongo]
	#   - _handle_s
	# SP: Construct query and mgProjection [Mongo]
	#   - _handle_rdftype
	#   - _handle_sp
	# SPO: Construct query and mgProjection [Mongo
	#   - _handle_spo
	# P
	#   - _handle_p
	# SO
	#   - _handle_so
	# PO
	#   - _handle_po
	# O
	#   - _handle_o
	#
	#
	# _handlePredicate
	# P:
	# 	- if rdf:type check model
	# 	- else check propName [Mongo]
	# PO 
	# 	- if rdf:type check model
	# 	- else check propName and value [Mongo]
	#
	# _handleObject
	# O
	# 	- determine value type, walk models, find type-matching fields, construct query and mgProjection
	#
	# @param ldf {object} the triple pattern (subject, predicate, object), offset and limit
	# @param tripleStream {stream} the trieple stream
	# @param doneLDF called when finished
	###
	handleLDFQuery: (ldf, tripleStream, metadataCallback, doneLDF) ->
		jsonldABoxOpts = {from: 'jsonld', to: 'json3'}
		metadataCallback or= ({totalCount}) -> log.debug("There are #{totalCount} triples available")
		ldf.offset or= 0
		ldf.limit  or= 10
		currentTriple = ldf.offset
		if not(ldf.subject or ldf.predicate or ldf.object)
			handler = '_handle_none'

		# Short-circtuit type queries
		if ldf.predicate and ldf.predicate is RDF_TYPE
			handler = '_handle_rdftype'
		else if ldf.subject
			handler = '_handle_s_sp_spo'
			if ldf.object and not ldf.predicate
				handler = '_handle_so'
		else if ldf.predicate
			if ldf.object
				handler = '_handle_po'
			else
				handler = '_handle_p'
		else if ldf.object
			handler = '_handle_o'
		else
			handler = '_handle_none'
		log.debug("LDF Query", ldf)
		log.debug("Handling query with #{handler}")
		if not @[handler]
			throw "Handler not Implemented: #{handler}"
		return @[handler].call @, ldf, tripleStream, metadataCallback, (err, count) ->
			doneLDF err, count

	###
	# From http://www.hydra-cg.com/spec/latest/triple-pattern-fragments/#controls
	#
	# <http://example.org/example#dataset>
	# void:subset <http://example.org/example?s=http%3A%2F%2Fexample.org%2Ftopic>;
	# hydra:search [
	#   hydra:template "http://example.org/example{?s,p,o}";
	#   hydra:mapping  [ hydra:variable "s"; hydra:property rdf:subject ],
	#                  [ hydra:variable "p"; hydra:property rdf:predicate ],
	#                  [ hydra:variable "o"; hydra:property rdf:object ]
	# ].
	###
	_hydraControls : (ldfQuery, tripleStream, cb) ->
		controls =
			'@context':
				hydra: HYDRA
				void: VOID
				rdf: RDF
			'@id': "#{@baseURI}#{@apiPrefix}/ldf"
			'void:subset': '@id': @_canonical(ldfQuery)
			'hydra:search':
				'hydra:template': "#{@baseURI}#{@apiPrefix}/lds{?subject,predicate,object}"
				'hydra:mapping': [
					{
						'hydra:variable': 'subject'
						'hydra:property': '@id': RDF + 'subject'
					},{
						'hydra:variable': 'predicate'
						'hydra:property': '@id': RDF + 'predicate'
					},{
						'hydra:variable': 'object'
						'hydra:property': '@id': RDF + 'object'
					}
				]
		next = @_next(ldfQuery)
		controls['hydra:next'] = {'@id':next} if next 
		previous = @_previous(ldfQuery)
		controls['hydra:previous'] = {'@id':previous} if previous
		log.silly 'Hypermedia controls', controls
		return @_pushTriples controls, tripleStream, {}, cb

	_next : (_ldfQuery) ->
		ldfQuery = {}
		ldfQuery[k] = v for k,v of _ldfQuery
		ldfQuery.offset += ldfQuery.limit
		return @_canonical ldfQuery

	_previous : (_ldfQuery) ->
		return null if _ldfQuery.offset == 0
		ldfQuery = {}
		ldfQuery[k] = v for k,v of _ldfQuery
		ldfQuery.offset -= ldfQuery.limit
		ldfQuery.offset = Math.max 0, ldfQuery.offset
		return @_canonical ldfQuery

	_canonical : (ldfQuery) ->
		ret = "#{@baseURI}/#{@ldfEndpoint}"
		qs = []
		qs.push "#{k}=#{encodeURIComponent v}" for k,v of ldfQuery
		return "#{ret}?#{qs.join '&'}"

	#==================================================
	#
	# Handlers
	#
	#==================================================

	_handle_p : (ldf, tripleStream, metadataCallback, doneLDF) ->
		allModelCount = 0
		innerMetadataCallback = ({totalCount}) -> allModelCount += totalCount
		@_uriToName ldf.predicate, (err, propName) =>
			return doneLDF err if err
			log.debug "propName: #{propName}"
			mgQueryDoc = {}
			mgProjection = {_id:true}
			mgQueryDoc[propName] = {$exists:true}
			mgProjection[propName] = true
			@_queryAllModels ldf, tripleStream, innerMetadataCallback, mgQueryDoc, mgProjection, (err) =>
				if err
					log.error err
					return doneLDF err
				metadataCallback {totalCount: allModelCount}
				doneLDF()

	_handle_none : (ldf, tripleStream, metadataCallback, doneLDF) ->
		totalCount = 0
		asyncCallback = (metadata) -> totalCount += metadata.totalCount
		mgQueryDoc = {}
		mgProjection = {_id:true}
		nrFound = 0
		Async.eachSeries @models, (model, doneModel) =>
			if nrFound > ldf.limit
				return doneModel()
			model.count (err, totalCount) =>
				log.debug("Total count for #{model.modelName}", totalCount)
				return doneModel err if err
				metadataCallback {totalCount}
				query = model.where(mgQueryDoc, mgProjection)
				query.limit(ldf.limit)
				query.exec (err, things) =>
					return doneModel err if err
					Async.each things, (thing, doneThing) =>
						@_pushTriples thing.jsonldABox(), tripleStream, ldf, (err, tripleCount) =>
							nrFound += tripleCount
							log.debug nrFound
							doneThing()
					, doneModel
		, (err) ->
			log.error err if err
			return doneLDF err if err
			metadataCallback {totalCount}
			doneLDF()

	_handle_s_sp_spo : (ldf, tripleStream, metadataCallback, doneLDF) ->
		@_tokenizeInstanceURI ldf.subject, (err, model, _id) =>
			return doneLDF err if err
			mongoQuery = {_id}
			if ldf.predicate
				return @_uriToName ldf.predicate, (err, propName) =>
					return doneLDF err if err
					if ldf.object
						mongoQuery[propName] = @_typeifyString(ldf.object)
					else
						mongoQuery[propName] = {$exists:true}
					return @_executeModelQuery ldf, model, mongoQuery, tripleStream, metadataCallback, doneLDF
			else
				return @_executeModelQuery ldf, model, mongoQuery, tripleStream, metadataCallback, doneLDF

	# <a id='_handle_rdftype'/>
	_handle_rdftype : (ldf, tripleStream, metadataCallback, doneLDF) ->
		if ldf.subject
			@_tokenizeInstanceURI ldf.subject, (err, model, id) =>
				return doneLDF err if err
				tripleStream.push {
					subject: ldf.subject
					predicate: RDF_TYPE
					object: @uriForClass(model.modelName)
				}
				metadataCallback {totalCount}
				doneLDF()
		else if ldf.object
			@_tokenizeClassURI ldf.object, (err, model) =>
				return doneLDF err if err
				@_queryModelRdfType model, tripleStream, metadataCallback, (err, totalCount) ->
					return doneLDF err if err
					metadataCallback {totalCount}
					doneLDF()
		else
			totalCount = 0
			asyncCallback = (metadata) -> totalCount += metadata.totalCount
			Async.each @models, (model, doneModel) =>
				@_queryModelRdfType model, tripleStream, asyncCallback, doneModel
			, (err) ->
				return doneLDF err if err
				metadataCallback {totalCount}
				doneLDF()

	#==================================================
	#
	# Query MongoDB
	#
	#==================================================

	_queryModelRdfType:	(model, tripleStream, metadataCallback, doneLDF) ->
		mgQueryDoc = {}
		mgProjection = {_id:true}
		model.count (err, totalCount) =>
			metadataCallback {totalCount}
			model.find mgQueryDoc, mgProjection, (err, things) =>
				return doneLDF err if err
				for thing in things
					tripleStream.push {
						subject: thing.uri()
						predicate: RDF_TYPE
						object: @uriForClass(model.modelName)
					}
				doneLDF()

	_executeModelQuery : (ldf, model, mongoQuery, tripleStream, metadataCallback, doneLDF) ->
		log.debug("Mongo query", mongoQuery)
		query = model.where mongoQuery
		query.findOne (err, thing) =>
			return doneLDF err if err
			@_pushTriples thing.jsonldABox(), tripleStream, ldf, (err, totalCount) ->
				return doneLDF err if err
				metadataCallback {totalCount}
				doneLDF()

	_queryAllModels :  (ldf, tripleStream, metadataCallback, mgQueryDoc, mgProjection, doneLDF) ->
		thingHandler = (thing, doneThing) =>
			@_pushTriples thing.jsonldABox(), tripleStream, ldf, (err, tripleCount) =>
				log.debug "Added #{tripleCount} triples"
				return doneThing()
		modelHandler = (model, doneModel) =>
			if ldf.found > ldf.limit
				return doneModel()
			model.count (err, modelCount) =>
				return doneModel(err) if err
				return doneModel() if modelCount is 0
				log.debug("Total count for #{model.modelName}", modelCount)
				metadataCallback {totalCount: modelCount}
				if ldf.offset > modelCount
					log.debug "Offset beyond model '#{model.modelName}' (#{ldf.offset} > #{modelCount})"
					log.debug "Skip to next model"
					ldf.offset = 0
					return doneModel()
				query = model.find(mgQueryDoc, mgProjection)
				log.debug("Querying MongoDB", mgQueryDoc, mgProjection)
				query.skip(ldf.offset)
				query.limit(ldf.limit)
				query.exec (err, things) =>
					return doneModel(err) if err
					log.debug "Things #{things.length}"
					Async.eachSeries things, thingHandler, (err) ->
						return doneModel(err) if err
						return doneModel()
		Async.eachSeries @models, modelHandler, doneLDF

	#==================================================
	#
	# Helpers
	#
	#==================================================

	_pushTriples : (thing, tripleStream, filter, cb) ->
		return @jsonldRapper.convert thing, 'jsonld', 'json3', (err, json3) ->
			if err
				log.error err
				cb err
			count = 0
			for triple in json3
				skip = false
				for pos in ['subject','predicate','object']
					if pos of filter
						skip = triple[pos] isnt filter[pos]
						if skip
							log.debug "Skip because '#{pos}': #{triple[pos]} isnt #{filter[pos]}"
							break
				continue if skip
				tripleStream.push triple
				count += 1
			cb null, count

	_uriToName: (url,cb) ->
		if url.indexOf(@schemaBaseURI) isnt 0
			return cb "Not in schemo: #{url}"
		return cb null, url.substring(@schemaBaseURI.length)

	_tokenizeClassURI: (url, cb) ->
		@_uriToName url, (err, modelName) =>
			return cb err if err
			modelName = modelName.substring(0,1).toUpperCase() + modelName.substring(1)
			if modelName not of @models
				return cb "No such model: #{modelName}"
			return cb null, @models[modelName]

	_tokenizeInstanceURI: (url, cb) ->
		if url.indexOf(@apiBaseURI) isnt 0
			return cb 'Not in schemo'
		url = url.replace(@apiBaseURI, '')
		if url.indexOf('/') == -1
			return cb 'Invalid URL (Missing slash between model and id)'
		[modelName, id] = url.split '/'
		modelName = modelName.substring(0,1).toUpperCase() + modelName.substring(1)
		if modelName not of @models
			return cb "No such model #{modelName}"
		return cb null, @models[modelName], id

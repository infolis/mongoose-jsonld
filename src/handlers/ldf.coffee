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
			log.debug "Handling LDF query", ldfQuery
			tripleStream = []

			#TODO
			res.end()
			# @handleLDFQuery ldfQuery, tripleStream, (err) =>
			#     @_hydraControls ldfQuery, tripleStream, (err) =>
			#         acceptable = Accepts(req).types()
			#         if acceptable.length == 0 or 'application/n3+json' in acceptable
			#             res.send tripleStream
			#         else
			#             @jsonldRapper.convert tripleStream, 'json3', 'jsonld', (err, converted) =>
			#                 req.jsonld = converted
			#                 res.locals.is_ldf = true
			#                 res.locals[k] = v for k,v of ldfQuery
			#                 @expressJsonldMiddleware(req, res, next)
		done()

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
		ret = "#{@baseURI}/#{@ldfEndpoint()}"
		qs = []
		qs.push "#{k}=#{encodeURIComponent v}" for k,v of ldfQuery
		return "#{ret}?#{qs.join '&'}"

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

	_pushTriples : (thing, tripleStream, filter={}, cb) ->
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
						break if skip
				continue if skip
				tripleStream.push triple
				count += 1
			cb null, count

	_tokenizeClassURI: (url, cb) ->
		if url.indexOf(@schemaBaseURI) isnt 0
			return cb "Not in schemo: #{url}"
		modelName = url.substring(@schemaBaseURI.length)
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

	###
	# 
	# _handleSubject
	# S: Construct query [Mongo]
	# SP: Construct query and projection [Mongo]
	# SPO: Construct query and projection [Mongo
	#
	# _handlePredicate
	# P:
	# 	- if rdf:type check model
	# 	- else check prop [Mongo]
	# PO 
	# 	- if rdf:type check model
	# 	- else check prop and value [Mongo]
	#
	# _handleObject
	# O
	# 	- determine value type, walk models, find type-matching fields, construct query and projection
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
		if typeof ldf.subject isnt 'undefined'
			handler = @_handleSubject
		else if typeof ldf.predicate isnt 'undefined'
			handler = @_handlePredicate
		else if typeof ldf.object isnt 'undefined'
			handler = _handleObject
		else
			handler = @_handleNone
		return handler.call @, ldf, tripleStream, metadataCallback, (err, count) ->
			doneLDF err, count

	_handleSubject : (ldf, tripleStream, metadataCallback, doneLDF) ->
		@_tokenizeInstanceURI ldf.subject, (err, model, id) =>
			return doneLDF() if err
			query = model.where {_id:id}
			query.findOne (err, thing) =>
				return doneLDF() if err
				@_pushTriples thing.jsonldABox(), tripleStream, ldf, (err, totalCount) ->
					return doneLDF err if err
					metadataCallback {totalCount}
					doneLDF()

	_handlePredicate : (ldf, tripleStream, metadataCallback, doneLDF) ->
		self = this
		if ldf.predicate is RDF_TYPE
			return @_handlePredicateRdfType.apply(@, arguments)
		# Async

	_handlePredicateRdfType : (ldf, tripleStream, metadataCallback, doneLDF) ->
		if ldf.object
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

	_queryModelRdfType:	(model, tripleStream, metadataCallback, doneLDF) ->
		self = this
		queryDoc = {}
		projection = {_id:true}
		model.count (err, totalCount) ->
			metadataCallback {totalCount}
			model.find queryDoc, projection, (err, things) ->
				return doneLDF err if err
				for thing in things
					tripleStream.push {
						subject: thing.uri()
						predicate: RDF_TYPE
						object: self.uriForClass(model.modelName)
					}
				doneLDF()

		# find the right model if any
		# find the document for the id

		# Async.forEachOfSeries @models, (model, modelName, doneModel) =>
		#     mongoQuery = @_buildMongoQuery(ldf, model)
		#     log.silly "Mongo query:", mongoQuery
		#     query = model.find mongoQuery
		#     query.exec (err, docs) =>
		#         return doneModel err if err
		#         Async.eachLimit docs, 20, (doc, doneDocs) =>
		#             doc.jsonldABox jsonldABoxOpts, (err, triples) =>
		#                 Async.eachSeries triples, (triple, doneField) =>
		#                     # if ldf.predicate and Utils.lastUriSegment(triple.predicate) is 'type'
		#                     if ldf.object and not Utils.literalValueMatch(triple.object, ldf.object)
		#                         return doneField()
		#                     else if ldf.predicate and not Utils.lastUriSegmentMatch(triple.predicate, ldf.predicate)
		#                         return doneField()
		#                     currentTriple += 1
		#                     if currentTriple > ldf.offset + ldf.limit
		#                         return doneField "max count reached (#{currentTriple} > #{ldf.offset} + #{ldf.limit})"
		#                     else if currentTriple > ldf.offset
		#                         tripleStream.push triple
		#                     return doneField()
		#                 , (err) ->
		#                     log.silly "Done with fields of #{doc.uri()}: #{err}"
		#                     return doneDocs err
		#         , (err) ->
		#             log.silly "Done with documents in '#{modelName}': #{err}", currentTriple
		#             return doneModel err
		# , (err) ->
		#     log.silly "Finished query: #{err}"
		#     log.logstop('handle-ldf')
		#     if err instanceof Error
		#         doneLDF err
		#     else
		#         doneLDF null, tripleStream

	_buildMongoQuery : (ldf, model) ->
		mongoQuery = {}
		if ldf.subject
			mongoQuery._id = Utils.lastUriSegment(ldf.subject)
		if ldf.object
			ldf.object = Utils.literalValue(ldf.object)
		if ldf.predicate and ldf.predicate isnt 'type'
			if ldf.object
				clause = @_make_clause(model, Utils.lastUriSegment(ldf.predicate), ldf.object)
				if clause
					mongoQuery[k] = v for k,v of clause
			else
				mongoQuery[Utils.lastUriSegment(ldf.predicate)] = {$exists:true}
		else if ldf.object
			orQuery = []
			for field in model.properFields()
				clause = @_make_clause(model, field, ldf.object)
				orQuery.push clause if clause
			mongoQuery['$or'] = orQuery
		return mongoQuery

	_make_clause: (model, field, value) ->
		clause = {}
		if field not of model.schema.paths
			return null
		fieldType = model.schema.paths[field].instance
		if fieldType is 'Number'
			clause[field] = value if Utils.isNumber(value)
		else if fieldType is 'Date'
			clause[field] = value if Utils.isDate(value)
		else
			clause[field] = value
		if Object.keys(clause).length > 0
			return clause
		return null


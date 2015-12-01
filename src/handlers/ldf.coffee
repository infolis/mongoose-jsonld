Async   = require 'async'
Accepts = require 'accepts'
Utils   = require '../utils'
Base    = require '../base'

log = require('../log')(module, level: 'silly')

HYDRA    = "http://www.w3.org/ns/hydra/core#"
ENDS     = 'http://labs.mondeca.com/vocab/endpointStatus#'
VOID     = "http://rdfs.org/ns/void#"
RDF      = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
XSD      = 'http://www.w3.org/2001/XMLSchema#'
RDF_TYPE = RDF + "type"

DEFAULT_LIMIT = 10

module.exports = class LdfHandlers extends Base

	constructor: ->
		super
		@apiBaseURI = "#{@baseURI}#{@apiPrefix}/"
		@schemaBaseURI = "#{@baseURI}#{@schemaPrefix}/"
		@ldfEndpoint = "#{@apiPrefix}/ldf"

	inject: (app, done) ->
		app.get @ldfEndpoint, (req, res, next) =>
			ldf = req.query
			ldf.controls  = false
			ldf.limit     = parseInt(req.query.limit) or DEFAULT_LIMIT
			ldf.offset    = parseInt(req.query.offset) or 0
			ldf.subject   = req.query.subject
			ldf.predicate = req.query.predicate
			ldf.object    = req.query.object
			for pos in ['subject','predicate','object']
				if ldf[pos] is '' or typeof ldf[pos] is 'undefined'
					delete ldf[pos]
			tripleStream = []

			totalCount = 0
			metadataCallback = (metadata) ->
				totalCount += metadata.totalCount

			if ldf.controls
				handler = @handleLDFQuery
			else
				handler = @handleLDFQueryWithControls
			handler.call @, ldf, tripleStream, metadataCallback, (err) =>
				acceptable = Accepts(req).types()
				if acceptable.length == 0 or 'application/n3+json' in acceptable
					res.send tripleStream
				else
					@jsonldRapper.convert tripleStream, 'json3', 'jsonld', (err, converted) =>
						req.jsonld = converted
						res.locals.is_ldf = true
						res.locals[k] = v for k,v of ldf
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
		ldf.offset or= 0
		ldf.limit  or= DEFAULT_LIMIT
		# Short-circtuit type queries
		if ldf.predicate and ldf.predicate is RDF_TYPE
			handler = '_handle_rdftype'
		else if ldf.subject
			handler = '_handle_s_sp_spo_so'
		else if ldf.predicate
			handler = '_handle_p_po'
		else
			handler = '_handle_none_o'
		log.debug("LDF Query", ldf)
		log.debug("Handling query with #{handler}")
		if not @[handler]
			throw "Handler not Implemented: #{handler}"
		return @[handler].call @, ldf, tripleStream, metadataCallback, doneLDF

	handleLDFQueryWithControls : (ldf, tripleStream, metadataCallback, doneLDF) ->
		metadata = {
			totalCount: 0
		}
		_start = process.hrtime()
		innerMetadataCallback = (metadataArg) ->
			if 'totalCount' of metadataArg
				metadata.totalCount += metadataArg.totalCount
			metadataCallback metadata
			log.debug("There are #{metadata.totalCount} triples available")
		@handleLDFQuery ldf, tripleStream, innerMetadataCallback, (err) =>
			return doneLDF err if err
			metadata.queryTime = @_msPassed _start
			@_hydraControls ldf, tripleStream, metadata, doneLDF

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
	_hydraControls : (ldf, tripleStream, metadata, cb) ->
		controls =
			'@context':
				hydra: HYDRA
				void: VOID
				rdf: RDF
				ends: ENDS
			'@id': "#{@baseURI}#{@apiPrefix}/ldf"
			'void:documents': metadata.totalCount
			'ends:statusResponseTime': metadata.queryTime
			'void:subset': '@id': @_canonical(ldf)
			# 'hydra:search':
			#     'hydra:template': "#{@baseURI}#{@apiPrefix}/lds{?subject,predicate,object}"
			#     'hydra:mapping': [
			#         {
			#             'hydra:variable': 'subject'
			#             'hydra:property': '@id': RDF + 'subject'
			#         },{
			#             'hydra:variable': 'predicate'
			#             'hydra:property': '@id': RDF + 'predicate'
			#         },{
			#             'hydra:variable': 'object'
			#             'hydra:property': '@id': RDF + 'object'
			#         }
			#     ]
		next = @_next(ldf)
		controls['hydra:next'] = {'@id':next} if next
		previous = @_previous(ldf)
		controls['hydra:previous'] = {'@id':previous} if previous
		log.silly 'Hypermedia controls', controls
		return @_pushTriples controls, tripleStream, {}, cb

	_next : (_ldf) ->
		ldf = {}
		ldf[k] = v for k,v of _ldf
		ldf.offset += ldf.limit
		return @_canonical ldf

	_previous : (_ldf) ->
		return null if _ldf.offset == 0
		ldf = {}
		ldf[k] = v for k,v of _ldf
		ldf.offset -= ldf.limit
		ldf.offset = Math.max 0, ldf.offset
		return @_canonical ldf

	_canonical : (ldf) ->
		ret = "#{@baseURI}#{@ldfEndpoint}"
		qs = []
		qs.push "#{k}=#{encodeURIComponent v}" for k,v of ldf
		return "#{ret}?#{qs.join '&'}"

	#==================================================
	#
	# Handlers
	#
	#==================================================

	# <a name="_handle_p"/>
	# <a name="_handle_po"/>
	_handle_p_po : (ldf, tripleStream, metadataCallback, doneLDF) ->
		allModelCount = 0
		innerMetadataCallback = ({totalCount}) -> allModelCount += totalCount
		@_uriToName ldf.predicate, (err, propName) =>
			return doneLDF err if err
			log.debug "propName: #{propName}"
			mgQueryDoc = {}
			mgProjection = {_id:true}
			if ldf.object
				mgQueryDoc[propName] = @_untypeifyString(ldf.object)
			else
				mgQueryDoc[propName] = {$exists:true}
			mgProjection[propName] = true
			@_queryAllModels ldf, tripleStream, innerMetadataCallback, mgQueryDoc, mgProjection, (err) =>
				if err
					log.error err
					return doneLDF err
				metadataCallback {totalCount: allModelCount}
				doneLDF()

	# <a name="_handle_none"/>
	# <a name="_handle_o"/>
	_handle_none_o : (ldf, tripleStream, metadataCallback, doneLDF) ->
		totalCount = 0
		asyncCallback = (metadata) -> totalCount += metadata.totalCount
		mgQueryDoc = {}
		mgProjection = {_id:true}
		nrFound = 0
		@_tokenizeClassURI ldf.object, (err) =>
			unless err
				return @_handle_rdftype ldf, tripleStream, metadataCallback, doneLDF
			Async.eachSeries @models, (model, doneModel) =>
				if nrFound > ldf.limit
					return doneModel()
				model.count (err, totalCount) =>
					log.silly("Total count for #{model.modelName}", totalCount)
					return doneModel err if err
					asyncCallback {totalCount}
					query = model.where(mgQueryDoc, mgProjection)
					query.limit(ldf.limit)
					query.exec (err, things) =>
						return doneModel err if err
						Async.each things, (thing, doneThing) =>
							@_pushTriples thing.jsonldABox(), tripleStream, ldf, (err, tripleCount) =>
								nrFound += tripleCount
								doneThing()
						, doneModel
			, (err) ->
				log.error err if err
				return doneLDF err if err
				metadataCallback {totalCount}
				doneLDF()

	# <a id='_handle_s'/>
	# <a id='_handle_sp'/>
	# <a id='_handle_spo'/>
	# <a id='_handle_so'/>
	_handle_s_sp_spo_so : (ldf, tripleStream, metadataCallback, doneLDF) ->
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
				metadataCallback {totalCount: 1}
				doneLDF()
		else if ldf.object
			@_tokenizeClassURI ldf.object, (err, model) =>
				return doneLDF err if err
				@_queryModelRdfType model, tripleStream, metadataCallback, doneLDF
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
			return doneLDF err if err
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
		log.silly("Mongo query", mongoQuery)
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
				log.silly "Added #{tripleCount} triples"
				return doneThing()
		modelHandler = (model, doneModel) =>
			if ldf.found > ldf.limit
				return doneModel()
			model.count (err, modelCount) =>
				return doneModel(err) if err
				return doneModel() if modelCount is 0
				log.silly("Total count for #{model.modelName}", modelCount)
				metadataCallback {totalCount: modelCount}
				if ldf.offset > modelCount
					log.debug "Offset beyond model '#{model.modelName}' (#{ldf.offset} > #{modelCount})"
					log.silly "Skip to next model"
					ldf.offset = 0
					return doneModel()
				query = model.find(mgQueryDoc, mgProjection)
				log.debug("Querying MongoDB", mgQueryDoc, mgProjection)
				query.skip(ldf.offset)
				query.limit(ldf.limit)
				query.exec (err, things) =>
					return doneModel(err) if err
					log.silly "Things #{things.length}"
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
				return cb err
			count = 0
			for triple in json3
				skip = false
				for pos in ['subject','predicate','object']
					if pos of filter
						if pos is 'object'
							skip = not Utils.literalValueMatch(triple[pos], filter[pos])
						else
							skip = triple[pos] isnt filter[pos]
						if skip
							log.silly "Skip because '#{pos}': #{triple[pos]} isnt #{filter[pos]}"
							break
				continue if skip
				tripleStream.push triple
				count += 1
			cb null, count

	_uriToName: (url,cb) ->
		return cb "Undefined url" unless url
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

	_typeifyString : (str) ->
		# TODO handle non-string input
		if str.indexOf '"' is 0
			return str
		return "\"#{str}\"^^#{XSD}string"

	_untypeifyString : (str) ->
		# TODO edge cases, numbers etc.
		val = Utils.literalValue(str)
		return val if val
		return str

	_msPassed : (ts) ->
		passed = process.hrtime ts
		return parseInt((passed[0]*1000) + (passed[1]/1000000))



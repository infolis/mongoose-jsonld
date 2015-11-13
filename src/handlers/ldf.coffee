Async = require 'async'
Utils = require '../utils'
Base  = require '../base'

log = require('../log')(module)

module.exports = class LdfHandlers extends Base

	inject: (app, nextMiddleware) ->
		app.get "/#{@apiPrefix}/ldf", (req, res) ->
			# TODO
			res.end()

	###
	#
	# if !(subject | predicate | object)
	# else if (subject)
	# if 'subject' and not 'predicate' and not 'object'
	# 	doc.jsonldABox -> content-negotiate
	# if 
	#
	# 	for model in @models
	# 		for doc in model.find query
	# 			jsonldABox to json3
	# @param ldf {object} the triple pattern (subject, predicate, object), offset and limit
	# @param tripleStream {stream} the trieple stream
	# @param doneLDF called when finished
	###
	handleLinkedDataFragmentsQuery: (ldf, tripleStream, doneLDF) ->
		jsonldABoxOpts = {from: 'jsonld', to: 'json3'}

		ldf.offset or= 0
		ldf.limit  or= 10

		currentTriple = 0
		Async.forEachOfSeries @models, (model, modelName, doneModel) =>
			mongoQuery = @_buildMongoQuery(ldf, model)
			log.silly "Mongo query:", mongoQuery
			query = model.find mongoQuery
			query.exec (err, docs) =>
				return doneModel err if err
				Async.eachLimit docs, 10, (doc, doneDocs) =>
					doc.jsonldABox jsonldABoxOpts, (err, triples) =>
						Async.each triples, (triple, doneField) =>
							if ldf.predicate and not Utils.lastUriSegmentMatch(triple.predicate, ldf.predicate)
								return doneField()
							# if ldf.object and not Utils.literalValueMatch(triple.object, ldf.object)
								# return doneField()
							currentTriple += 1
							if currentTriple > ldf.offset + ldf.limit
								return doneField "max count reached (#{currentTriple} > #{ldf.offset} + #{ldf.limit})"
							else if currentTriple > ldf.offset
								tripleStream.push triple
							return doneField()
						, (err) ->
							log.silly "Done with fields of #{doc.uri()}: #{err}"
							return doneDocs err
				, (err) ->
					log.silly "Done with documents in '#{modelName}': #{err}", currentTriple
					return doneModel err
		, (err) ->
			log.silly "Finished query: #{err}"
			if err instanceof Error
				doneLDF err
			else
				doneLDF null, tripleStream

	_buildMongoQuery : (ldf, model) ->
			mongoQuery = {}
			if ldf.object
				ldf.object = Utils.literalValue(ldf.object)
			if ldf.subject
				mongoQuery._id = Utils.lastUriSegment(ldf.subject)
			if ldf.predicate and ldf.object
				clause = @_make_clause(model, Utils.lastUriSegment(ldf.predicate), ldf.object)
				if clause
					mongoQuery[k] = v for k,v of clause
			else if ldf.predicate
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


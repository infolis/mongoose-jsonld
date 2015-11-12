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
	# @param ldfQuery {object} the triple pattern (subject, predicate, object), offset and limit
	# @param tripleStream {stream} the trieple stream
	# @param doneLDF called when finished
	###
	handleLinkedDataFragmentsQuery: (ldfQuery, tripleStream, doneLDF) ->
		mongoQuery = {}
		jsonldABoxOpts = {from: 'jsonld', to: 'json3'}
		if ldfQuery.subject
			mongoQuery._id = Utils.lastUriSegment(ldfQuery.subject)
		# if ldfQuery.predicate
			# path = Utils.lastUriSegment(ldfQuery.predicate)
			# mongoQuery[path] = {$exists:true}
			# jsonldABoxOpts.filter_predicate = [path]

		ldfQuery.offset or= 0
		ldfQuery.limit  or= 10
		log.debug mongoQuery

		currentTriple = 0
		Async.forEachOfSeries @models, (model, modelName, doneModel) =>
			query = model.find mongoQuery
			query.exec (err, docs) =>
				return doneModel err if err
				Async.eachLimit docs, 10, (doc, doneDocs) =>
					doc.jsonldABox jsonldABoxOpts, (err, triples) =>
						Async.eachLimit triples, ldfQuery.limit, (triple, doneField) =>
							if ldfQuery.predicate and not Utils.lastUriSegmentMatch(triple.predicate, ldfQuery.predicate)
								return doneField()
							# XXX SLOoooooOOoooOW
							if ldfQuery.object and not Utils.literalValueMatch(triple.object, ldfQuery.object)
								return doneField()
							currentTriple += 1
							if currentTriple > ldfQuery.offset + ldfQuery.limit
								return doneField "max count reached (#{currentTriple} > #{ldfQuery.offset} + #{ldfQuery.limit})"
							else if currentTriple > ldfQuery.offset
								tripleStream.push triple
							return doneField()
						, (err) ->
							log.silly "Done with fields of #{doc.uri()}: #{err}"
							return doneDocs err
				, (err) ->
					log.debug "Done with documents in '#{modelName}': #{err}", currentTriple
					return doneModel err
		, (err) ->
			log.debug "Finished query: #{err}"
			if err instanceof Error
				doneLDF err
			else
				doneLDF null, tripleStream

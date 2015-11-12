Async = require 'async'
Utils = require '../utils'
Base  = require '../base'

module.exports = class LdfHandlers extends Base

	inject: (app, nextMiddleware) ->

	handleLinkedDataFragmentsQuery: (ldfQuery, tripleStream, doneLDF) ->
		mongoQuery = {}
		projection = null
		if ldfQuery.subject
			mongoQuery._id = Utils.lastUriSegment(ldfQuery.subject)
		if ldfQuery.predicate
			projection = Utils.lastUriSegment(ldfQuery.predicate)
			mongoQuery[projection] = {$exists:true}

		ldfQuery.offset or= 0
		ldfQuery.limit  or= 10
		console.log mongoQuery

		currentTriple = 0
		Async.forEachOfSeries @models, (model, modelName, doneModel) =>
			query = model.find mongoQuery
			if projection
				query.select(projection)
			query.exec (err, docs) =>
				return doneModel err if err
				Async.eachSeries docs, (doc, doneDocs) =>
					Async.forEachOfSeries doc.toJSON(), (v, k, doneField) =>
						return doneField() if Utils.INTERNAL_FIELD_REGEX.test k
						triples = []
						type = doc.schema.paths[k].options.type
						if typeof v is 'object'
							for vv in v
								triples.push @_makeTriple(doc, k, vv)
						else
							triples.push @_makeTriple(doc, k, v)
						for triple in triples
							currentTriple += 1
							if currentTriple > ldfQuery.offset + ldfQuery.limit
								return doneField "max count reached (#{currentTriple} > #{ldfQuery.offset} + #{ldfQuery.limit})"
							else if currentTriple > ldfQuery.offset
								tripleStream.push triple
						return doneField()
					, (err) ->
						# console.log "Done with fields of #{doc.uri()}: #{err}"
						return doneDocs err
				, (err) ->
					console.log "Done with documents in '#{modelName}': #{err}"
					console.log currentTriple
					return doneModel err
		, (err) ->
			console.log "Finished query: #{err}"
			doneLDF err

	_makeTriple: (doc, fieldName, value) ->
		subject: doc.uri()
		predicate: doc.uriForClass(fieldName)
		object: value


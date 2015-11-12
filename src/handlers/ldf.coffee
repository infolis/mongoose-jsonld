Async = require 'async'
Utils = require '../utils'
Base = require '../base'

log = require('../log')(module)

module.exports = class LdfHandlers extends Base

	inject: (app, nextMiddleware) ->
		app.get "/#{@apiPrefix}/ldf", (req, res) ->
			# TODO
			res.end()

	###
	#
	# if not ('subject' or 'predicate' or 'object')
	# 	for model in @models
	# if 'subject' and not 'predicate' and not 'object'
	# 	doc.jsonldABox -> content-negotiate
	# if 
	#
	# @param ldfQuery {object} the triple pattern (subject, predicate, object), offset and limit
	# @param tripleStream {stream} the trieple stream
	# @param doneLDF called when finished
	###
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
		log.debug mongoQuery

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
		log.debug doc.schema.options
		if typeof value is 'boolean'
			value = "\"#{value}\"^^<http://www.w3.org/2001/XMLSchema#boolean>"
		else if typeof value is 'number'
			value = "\"#{value}\"^^<http://www.w3.org/2001/XMLSchema#long>"
		subject: doc.uri()
		predicate: doc.uriForClass(fieldName)
		object: value


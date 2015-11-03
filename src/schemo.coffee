### 
# Schemo
###

Fs      = require 'fs'
TSON    = require 'tson'

Factory = require './factory'
Utils   = require './utils'
Base    = require './base'
Async   = require 'async'

module.exports = class Schemo extends Base

	constructor : (opts = {}) ->
		#
		# Call the base constructor
		#
		super
		#
		# Load the schema-ontology json
		#
		if not opts.schemo
			if opts.tson
				opts.schemo = TSON.load opts.tson
			else if opts.json
				opts.schemo = JSON.parse Fs.readFileSync opts.json
			else
				throw new Error("Must provide 'schemo' object to constructor")
		#
		# factory
		#
		@factory = new Factory(opts)
		#
		# instance properties
		#
		@schemas = {}
		@models = {}
		@onto = { 
			classes: {}
		}
		@handlers = {}
		for m in ['schema', 'restful', 'swagger']
			mod = require "./handlers/#{m}"
			@handlers[m] = new mod(@)

		#
		# Build the schemas and models
		#
		for className, classDef of @schemo
			if /^@/.test className
				@onto[className] = classDef
			else
				@addClass className, classDef

	addClass: (className, classDef) ->
		@schemas[className] = schema = @factory.createSchema(className, classDef, {strict: true})
		@models[className] = model = @mongoose.model(className, schema)
		@onto.classes[className] = model.jsonldTBox()

	handleLinkedDataFragmentsQuery: (ldfQuery, tripleStream, doneLDF) ->
		mongoQuery = {}
		if ldfQuery.subject
			mongoQuery._id = Utils.lastUriSegment(ldfQuery.subject)
			console.log mongoQuery
		ldfQuery.offset or= 0
		ldfQuery.limit  or= 10
		console.log ldfQuery
		maxTriple = ldfQuery.offset + ldfQuery.limit

		currentTriple = 0
		Async.forEachOfSeries @models, (model, modelName, doneModel) =>
			query = model.find mongoQuery
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
							if currentTriple > maxTriple
								return doneField 'max count reached'
							else if currentTriple > ldfQuery.offset
								tripleStream.push triple
						return doneField()
					, (err) ->
						console.log "Done with fields of #{doc.uri()}: #{err}"
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

	jsonldTBox : (opts, cb) ->
		if typeof opts == 'function' then [cb, opts] = [opts, {}]
		jsonld = {'@context':{}, '@graph':[]}
		for k,v of @onto
			if k is '@ns'
				jsonld['@context'] = v
			else if k is '@context'
				jsonld['@graph'].push v
			else
				for kk, vv of v
					jsonld['@graph'].push vv
		if cb
			return @serialize(jsonld, opts, cb)
		else
			return jsonld

### 
# Schemo
###

Fs           = require 'fs'
TSON         = require 'tson'

Factory = require './factory'
Utils   = require './utils'
Base    = require './base'
Async   = require 'async'

log = require('./log')(module)

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
		#
		# Build the schemas and models
		#
		for className, classDef of @schemo
			if /^@/.test className
				@onto[className] = classDef
			else
				@addClass className, classDef

		@checkForConflicts()
		@handlers = {}
		Async.eachSeries ['schema', 'restful', 'swagger', 'ldf'], (m, loaded) =>
			log.debug "Registering '#{m}' handler"
			@handlers[m] = new(require "./handlers/#{m}")(@)
			@handlers[m].once 'setUp', (err) ->
				log.info "Handler #{m} is go", err or ''
				return loaded()
			@handlers[m].setUp()
		, (err) =>
			@emit 'ready', err



	#
	# Sanity check that there are no conflicting names
	#
	checkForConflicts: ->
		@instanceNames = {}
		_lcInstanceNames = {}
		for modelName,model of @models
			@instanceNames[modelName] = true
			k = modelName.toLowerCase()
			_lcInstanceNames[k] or= []
			_lcInstanceNames[k].push modelName
			for field in model.properFields()
				@instanceNames[field] = true
				k = field.toLowerCase()
				_lcInstanceNames[k] or= []
				_lcInstanceNames[k].push "#{modelName}.#{field}"
		conflicts = {}
		for name,instances of _lcInstanceNames
			if instances.length > 1
				conflicts[name] = instances
		log.warn("Multiple classes/properties with very similar name:\n#{Utils.dump(conflicts)}")

	addClass: (className, classDef) ->
		@schemas[className] = schema = @factory.createSchema(className, classDef, {strict: true})
		@models[className] = model = @factory.createModel(className, schema)
		model.ensureIndexes()
		@onto.classes[className] = model.jsonldTBox()

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

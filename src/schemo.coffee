### 
# Schemo
###

Fs      = require 'fs'
TSON    = require 'tson'

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
		@handlers = {}
		for m in ['schema', 'restful', 'swagger', 'ldf']
			mod = require "./handlers/#{m}"
			log.info "Registering '#{m}' handler"
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

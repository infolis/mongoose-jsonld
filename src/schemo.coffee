### 
# Schemo
###

TSON    = require 'tson'
Fs      = require 'fs'
Factory = require './factory'
Utils    = require './utils'

module.exports = class Schemo

	constructor : (opts) ->
		opts or= {}
		if not opts.schemo
			if opts.tson
				opts.schemo = TSON.load opts.tson
			else if opts.json
				opts.schemo = JSON.parse Fs.readFileSync opts.json
			else
				throw new Error("Must provide 'schemo' object to constructor")
		if not opts.mongoose
			throw new Error("Need a Mongoose MongoDB Connection, provide 'mongoose' to constructor")
		#
		# Take all arguments
		#
		@[k]   = v for k,v of opts
		#
		# factory
		#
		@mongoose = opts.mongoose
		@factory = new Factory(opts)
		#
		# instance properties
		#
		@schemas = {}
		@models = {}
		@onto = {
			'@context': {}
			'@graph': []
		}
		#
		# Build the schemas and models
		#
		for schemaName, schemaDef of @schemo
			if schemaName is '@ns'
				@onto['@context'][ns] = uri for ns,uri of schemaDef
			else if schemaName is '@context'
				# TODO add id
				@onto['@graph'].push schemaDef
			else
				# console.log schemaName
				@schemas[schemaName] = schema = @factory.createSchema(schemaName, schemaDef, {strict: true})
				@models[schemaName] = @mongoose.model(schemaName, schema)
				@onto['@graph'].push @models[schemaName].jsonldTBox()

	jsonldTBox : (opts, cb) ->
		if typeof opts == 'function' then [cb, opts] = [opts, {}]
		if cb
			return @factory.utils.convert(@onto, opts, cb)
		else
			return @onto
	
	injectSchemaHandlers: ->
		# console.log @factory.utils.dump arguments
		return require('./handlers/jsonld').apply(@, arguments)

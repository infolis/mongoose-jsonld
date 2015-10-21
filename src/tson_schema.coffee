### 
# TSON (JSON) Based schema/ontology

###
TSON = require 'tson'
MongooseJSONLD = require './schema-factory'

module.exports = class TsonSchema

	constructor : (opts) ->
		opts or= {}
		@[k] = v for k,v of opts
		@pathToSchemology or= process.env['HOME'] + '/infolis-web/infolis.tson' 
		@schemology = TSON.load @pathToSchemology
		@ns = @schemology['@ns'] or {}
		if @schemology instanceof Error
			throw @schemology

		if not @mongoose
			throw new Error("Need a Mongoose MongoDB Connection, provide 'mongoose' to constructor")

		@mongooseJSONLD = new MongooseJSONLD(@)

		@schemas = {}
		@models = {}
		@onto = {
			'@context': {}
			'@graph': []
		}

		@_readSchemas()
		# @ontology = _readOntology(@schemology, @ns)
		# console.log @dbConnection.model

	_readSchemas : () ->
		for schemaName, schemaDef of @schemology
			if schemaName is '@ns'
				@onto['@context'][ns] = uri for ns,uri of schemaDef
			else if schemaName is '@context'
				# TODO add id
				@onto['@graph'].push schemaDef
			else
				schemaDef = JSON.parse JSON.stringify schemaDef
				# console.log schemaName
				# console.log schemaDef
				@schemas[schemaName] = @mongooseJSONLD.createSchema(schemaName, schemaDef, {strict: true})
				@models[schemaName] = @dbConnection.model(schemaName, @schemas[schemaName])
				@onto['@graph'].push @models[schemaName].jsonldTBox()

	jsonldTBox : (opts, cb) ->
		if typeof opts == 'function' then [cb, opts] = [opts, {}]
		if cb
			return @mongooseJSONLD._convert(@onto, opts, cb)
		else
			return @onto

module.exports = InfolisSchemas

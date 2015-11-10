YAML  = require 'yamljs'
Utils = require '../utils'
Base = require '../base'

log = require('../log')(module)

module.exports = class Swagger extends Base

	inject: (app, swaggerDef, nextMiddleware) ->
		swagger = "#{@apiPrefix}/swagger"
		swagger = "/swagger"
		log.debug "Swagger available at #{swagger}.yaml"
		app.get "#{swagger}.yaml", (req, res, next) =>
			res.header 'Content-Type', 'application/swagger+yaml'
			res.send YAML.stringify @getSwagger(swaggerDef), 10, 2
		log.debug "Swagger available at #{swagger}.json"
		app.get "#{swagger}.json", (req, res, next) =>
			res.header 'Content-Type', 'application/swagger+json'
			res.send JSON.stringify @getSwagger(swaggerDef)


	getSwagger: (swaggerDef) ->
		swaggerDef.swagger      or= '2.0'
		swaggerDef.basePath     or= '/'
		swaggerDef.info         or= {}
		swaggerDef.info.title   or= 'Untitled Mongoose-JSONLD powered API'
		swaggerDef.info.version or= '0.1'
		swaggerDef.tags         or= [
			{
				name: 'mongoose-jsonld'
				description: 'Automatically generated API'
			}
			{
				name: 'custom'
				description: 'Custom methods'
			}
		]
		swaggerDef.consumes or= [
			'application/json'
			'application/ld+json'
			'text/turtle'
			'text/n3'
			'text/n-triples'
			'application/rdf+xml'
		]
		swaggerDef.produces or= [
			'application/json'
			'application/ld+json'
			'text/turtle'
			'text/n3'
			'text/n-triples'
			'application/rdf+xml'
		]


		swaggerDef.paths or= {}
		swaggerDef.definitions or= {}
		for modelName, model of @models
			for k, v of @getSwaggerPath(model)
				swaggerDef.paths[k] = v
			for k, v of @getSwaggerDefinition(model)
				swaggerDef.definitions[k] = v

		return swaggerDef

	getSwaggerPath: (model) ->
		modelName = model.modelName
		modelNameLC = Utils.lcfirst model.modelName
		tags = ["mongoose-jsonld", "#{modelNameLC}"]

		ret = {}
		pathCollection = "#{@apiPrefix}/#{modelNameLC}"
		pathItem = "#{pathCollection}/{id}"
		pathCollectionDelete = "#{pathCollection}/!!"

		ret[pathCollection] = {}
		ret[pathItem]       = {}
		ret[pathCollectionDelete] = {}

		ret[pathCollection].get =
			tags: tags
			description: "Get every [#{modelName}](#{@schemaPrefix}/#{modelName})",
			parameters: [
				name: 'q'
				in: "query"
				description: "k-v-pairs to filter for. 'key1:value1,key2:value2'"
				required: false
				type: 'string'
			]
			responses:
				200:
					description: "Retrieved every [#{modelName}](#{@schemaPrefix}/#{modelName}"
					schema:
						type: 'array'
						items:
							$ref: "#/definitions/#{modelName}"

		ret[pathItem].get =
			tags: tags
			description: "Return #{modelName} with _id {id}",
			parameters: [
				in: "path"
				name: "id"
				description: "ID of the #{modelName} to retrieve"
				required: true
				type: 'string'
				format: 'uuid'
			]
			responses:
				201:
					description: "Found #{modelName}"
					schema:
						$ref: "#/definitions/#{modelName}"
				404:
					description: "#{modelName} not found."

		ret[pathCollection].post =
			tags: tags
			description: "Post a new #{modelName}",
			parameters: [
					name: modelNameLC
					in: "body"
					description: "Representation of the new #{model.modelName}"
					required: true
					schema:
						$ref: "#/definitions/#{modelName}"
			]
			responses:
				201:
					description: "Created a new #{modelName}"
				404:
					description: "#{modelName} not found."

		ret[pathItem].put =
			tags: tags
			description: "Replace #{modelName} with new #{modelName}",
			parameters: [
				in: "path"
				name: "id"
				description: "ID of the #{modelName} to replace"
				required: true
				type: 'string'
				format: 'uuid'
			]
			responses:
				201:
					description: "Replaced #{modelName}"
					schema:
						$ref: "#/definitions/#{modelName}"
				404:
					description: "#{modelName} not found."

		ret[pathItem].delete =
			tags: tags
			description: "Delete #{modelName} with _id {id}",
			parameters: [
				in: "path"
				name: "id"
				description: "ID of the #{modelName} to delete"
				required: true
				type: 'string'
			]
			responses:
				201:
					description: "It's done. #{modelName} {id} is gone."
				404:
					description: "#{modelName} not found."

		ret[pathCollectionDelete].delete =
			tags: tags
			description: "Delete all #{modelName}",
			responses:
				200:
					description: "Annihilated all #{modelName}"

		return ret

	getSwaggerDefinition: (model) ->
		ret = {}
		ret[model.modelName] = definition = {
			type: 'object'
		}
		definition.properties = {}
		definition.description = model.schema.options['@context']['dc:description']
			# "\n" +
			# "See also [#{model.modelName} RDF definition](/#{@schemaPrefix}/#{model.modelName})"
		definition.required = []

		for k, v of model.schema.paths
			if k.match /^_/
				continue
			if k == '@id'
				continue
			# if model.modelName == 'InfolisFile'
				# log.debug v
			if v.isRequired
				definition.required.push k
			propDef = {}
			if v.enumValues and v.enumValues.length > 0
				propDef.enum = v.enumValues
			type = Utils.lcfirst v.instance
			switch type
				when 'string', 'number', 'boolean'
					propDef.type = type
				when 'date'
					propDef.type = 'string'
					propDef.format = 'date-time'
				when 'array'
					propDef.type = type
					propDef.items = {type: 'string'}
				else
					log.error "UNKNOWN TYPE", type
			# if v.options['@context']['dc:example']
				# propDef.example = v.options['@context']['dc:example']
			# pathDef.type = v.
			definition.properties[k] = propDef
		if definition.required.length == 0
			delete definition.required
		return ret

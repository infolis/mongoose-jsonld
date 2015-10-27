Utils = require '../utils'
Base = require '../base'

module.exports = class SchemaHandlers extends Base

	inject: (app, nextMiddleware) ->
		for modelName, model of @models
			do =>
				path = "#{@schemaPrefix}/#{model.modelName}"
				console.log "Binding schema handler #{path}"
				app.get path, (req, res, next) =>
					# req.jsonld = model.schema.options['@context']
					req.jsonld = model.jsonldTBox()
					# console.log req.jsonld
					if not req.headers.accept or req.headers.accept in ['*/*', 'application/json']
						res.send JSON.stringify(req.jsonld, null, 2)
					else
						@expressJsonldMiddleware(req, res, next)
				for propPath, propDef of model.schema.paths
					continue if Utils.INTERNAL_FIELD_REGEX.test propPath
					# console.log propPath
					do (propDef) =>
						app.get "#{@schemaPrefix}/#{propPath}", (req, res, next) =>
							req.jsonld = propDef.options['@context']
							if not req.headers.accept or req.headers.accept in ['*/*', 'application/json']
								res.send JSON.stringify(req.jsonld, null, 2)
							else
								@expressJsonldMiddleware(req, res, next)

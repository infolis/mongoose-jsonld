Utils = require '../utils'
Base = require '../base'

log = require('../log')(module)

module.exports = class SchemaHandlers extends Base

	inject: (app, nextMiddleware) ->
		for modelName, model of @models
			do =>
				path = "#{@schemaPrefix}/#{model.modelName}"
				log.debug "Binding schema handler #{path}"
				app.get path, (req, res, next) =>
					# req.jsonld = model.schema.options['@context']
					req.jsonld = model.jsonldTBox()
					# log.debug req.jsonld
					if not req.headers.accept or req.headers.accept in ['*/*', 'application/json']
						res.send JSON.stringify(req.jsonld, null, 2)
					else
						@expressJsonldMiddleware(req, res, next)
				for propPath, propDef of model.schema.paths
					continue if Utils.INTERNAL_FIELD_REGEX.test propPath
					# log.debug propPath
					do (propDef) =>
						app.get "#{@schemaPrefix}/#{propPath}", (req, res, next) =>
							req.jsonld = propDef.options['@context']
							if not req.headers.accept or req.headers.accept in ['*/*', 'application/json']
								res.send JSON.stringify(req.jsonld, null, 2)
							else
								@expressJsonldMiddleware(req, res, next)

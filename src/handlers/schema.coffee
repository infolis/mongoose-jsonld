Utils = require '../utils'
JsonldRapper = require 'jsonld-rapper'
Base = require '../base'

log = require('../log')(module)

module.exports = class SchemaHandlers extends Base

	inject: (app, done) ->
		console.log @instanceNames
		@jsonldTBox {to: 'jsonld', profile: JsonldRapper.JSONLD_PROFILE.FLATTENED}, (err, expand) =>
			@serialize expand, {to: 'jsonld', profile: JsonldRapper.JSONLD_PROFILE.EXPANDED}, (err, flat) =>
				for def in flat
					do (def) =>
						name = Utils.lastUriSegment(def['@id'])
						path =  "#{@schemaPrefix}/#{name}"
						if name of @onto.classes
							def = @onto.classes[name]
						log.debug "Binding schema handler #{path}"
						app.get path, (req, res, next) =>
							req.jsonld = def
							if not req.headers.accept or req.headers.accept in ['*/*', 'application/json']
								res.send JSON.stringify(req.jsonld, null, 2)
							else
								@expressJsonldMiddleware(req, res, next)
		done()

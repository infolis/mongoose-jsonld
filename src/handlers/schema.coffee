Utils = require '../utils'
JsonldRapper = require 'jsonld-rapper'
Base = require '../base'

log = require('../log')(module)

module.exports = class SchemaHandlers extends Base

	isBlank: (id) -> id.indexOf('_:') == 0

	inject: (app, done) ->
		@jsonldTBox {to: 'jsonld', profile: JsonldRapper.JSONLD_PROFILE.FLATTENED}, (err, expand) =>
			@serialize expand, {to: 'jsonld', profile: JsonldRapper.JSONLD_PROFILE.EXPANDED}, (err, flat) =>
				indexed = {}
				blanks = {}
				blanks[def['@id']] = def for def in flat when @isBlank(def['@id'])
				for def in flat
					id = def['@id']
					if @isBlank(id) or id.indexOf(@baseURI) == -1
						continue
					name = Utils.lastUriSegment id
					graph = []
					if name of @onto.classes
						graph = @onto.classes[name]
					else
						graph.push def
						for __,objs of def
							continue if typeof objs is 'string'
							for obj in objs
								continue if typeof obj is 'string'
								if '@id' of obj and @isBlank(obj['@id'])
									graph.push blanks[obj['@id']]
					do (name, graph) =>
						path =  "#{@schemaPrefix}/#{name}"
						log.debug "Binding schema handler #{path}"
						app.get path, (req, res, next) =>
							req.jsonld = graph
							@expressJsonldMiddleware(req, res, next)
		done()

Merge = require 'merge'
JsonLD = require 'jsonld'

idSchema = {
	'@id': {
		'type': "String"
	}
}

# maps concise names to paths to be required
predefinedContexts = {
	'prefix.cc': './contexts/prefix.cc'
	'rdfa11': './contexts/rdfa11'
	'basic': './contexts/basic'
}

loadContext = (optsOrString) ->
	ctx = optsOrString || 'basic'
	# If this is a string but not a URL
	if typeof ctx is 'string' 
		if ctx.indexOf('/') == -1
			if not predefinedContexts[ctx]
				throw new Error "No such predefined context: #{ctx}"
			contextJson = require(predefinedContexts[ctx])
			ctx = contextJson['@context']
		else
			# TODO handle URLs somehow
	return ctx

# TODO remove unused prefixes
# removeUnused = (doc) ->

module.exports = (moduleOpts) ->
	moduleOpts or= {}
	moduleOpts.profile or= 'compact'
	moduleOpts.apiBase or= 'http://EXAMPLE.ORG/CHANGE-ME/API'
	moduleOpts.schemaBase or= 'http://EXAMPLE.ORG/CHANGE-ME/SCHEMA'

	moduleOpts.urlForInstance or= () ->
		apiBase = moduleOpts.apiBase
		collectionName = @.constructor.collection.name
		id = @._id
		return "#{apiBase}/#{collectionName}/#{id}"

	moduleOpts.urlForClass or= (short) ->
		return "#{moduleOpts.schemaBase}/#{short}"

	# Load the context up
	moduleOpts.expandContext = loadContext(moduleOpts.expandContext)

	# createManager: (schemology) ->
	#     for clazz, clazzObj of schemology
	#         clazzDef = clazzObj['jsonld']
		

	createPlugin: (schema, pluginOpts) ->
		pluginOpts or= {}
		pluginOpts = Merge(moduleOpts, pluginOpts)

		# Set the method for export IDs
		schema.methods.urlForInstance = pluginOpts.urlForInstance

		# Every model can have an '@id' field
		schema.add(idSchema)

		# Allow export of the Linked Data description of the schema
		schema.methods.jsonldABox = (methodOpts, cb) ->
			doc = @
			if typeof methodOpts == 'function'
				cb = methodOpts
				methodOpts = {}
			methodOpts = Merge(pluginOpts, methodOpts)
			
			obj = doc.toObject()

			# Set the @id to a dereferenceable URI
			obj['@id'] = doc.urlForInstance()

			# Delete '_id' unless explicitly kept
			unless methodOpts.keep_id
				delete obj._id

			# # TODO is this the right behavior
			obj['@context'] = {}
			# obj['@context'] = Merge(methodOpts.context, obj['@context'])
			# obj['@context'] = 'http://prefix.cc/context'

			for schemaPathName, schemaPathDef of doc.schema.paths
				# skip internal fields
				continue if /^_/.test schemaPathName
				continue if not schemaPathDef.options?['@context']
				obj['@context'][schemaPathName] = schemaPathDef.options['@context']
				enumValues = schemaPathDef.enum()?.enumValues
				if enumValues.length
					obj['@context'][schemaPathName]['rdfs:range'] = {
						'owl:oneOf': enumValues
						'@type': 'rdfs:Datatype'
					}

			# console.log obj['@context']
			switch moduleOpts.profile
				when 'compact', 'compacted'
					JsonLD.compact obj, Merge(obj['@context'], methodOpts.expandContext), {expandContext: methodOpts.expandContext}, cb
				when 'flatten', 'flattened'
					JsonLD.flatten obj, {}, {expandContext: methodOpts.expandContext}, cb
				when 'expand', 'expanded'
					JsonLD.flatten obj, {}, {expandContext: methodOpts.expandContext}, cb
				else
					throw new Error("No such profile: #{methodOpts.profile}")

		schema.statics.jsonldTBox = (methodOpts, cb) ->
			if typeof methodOpts is 'function'
				cb = methodOpts
				methodOpts = {}
			model = @
			methodOpts = Merge(pluginOpts, methodOpts)
			onto = []

			# Class def
			classDef = model.schema.options['@context'] || {}
			console.log classDef
			classDef['@id'] = methodOpts.urlForClass(model.modelName)
			onto.push classDef

			# Properties def
			for schemaPathName, schemaPathDef of model.schema.paths
				# skip internal fields
				continue if /^_/.test schemaPathName
				continue if /^@context/.test schemaPathName
				continue if not schemaPathDef.options?['@context']
				propertyDef = schemaPathDef.options['@context']
				if not propertyDef['@id']
					propertyDef['@id'] = methodOpts.urlForClass(schemaPathName)
				propertyDef['schema:domainIncludes'] = classDef['@id']
				propertyDef['@type'] = ['rdfs:Property']
				onto.push propertyDef

			# console.log onto

			switch moduleOpts.profile
				when 'compact', 'compacted'
					JsonLD.compact onto, methodOpts.expandContext, {expandContext: methodOpts.expandContext}, cb
				when 'flatten', 'flattened'
					JsonLD.flatten {}, Merge(onto, methodOpts.expandContext), {expandContext: methodOpts.expandContext}, cb
				when 'expand', 'expanded'
					JsonLD.flatten {}, Merge(onto, methodOpts.expandContext), {expandContext: methodOpts.expandContext}, cb
				else
					throw new Error("No such profile: #{methodOpts.profile}")


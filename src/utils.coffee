N3Util   = require('n3').Util
Inspect  = require('util').inspect
IsNumber = require('is-number')

module.exports = class Utils

	#
	# Regex for matching internal mongoose / mongodb fields
	#
	@INTERNAL_FIELD_REGEX: /^[\$_]/

	@JSONLD_FIELD_REGEX: /^@/

	@CONTEXT_FIELD_REGEX: /^@context$/

	#
	# @return {string} lower-case the first letter of a string
	#
	@lcfirst : (str) ->
		str.substr(0,1).toLowerCase() + str.substr(1)

	#
	# Everything after the last '/' slash or the '#' fragment separator
	#
	@lastUriSegment : (uri) ->
		if uri.indexOf('http') isnt 0
			return uri.substr(uri.indexOf(':') + 1)
		if uri.indexOf('#') > -1
			return uri.substr(uri.lastIndexOf('#') + 1)
		else if uri.indexOf('/') > -1
			return uri.substr(uri.lastIndexOf('/') + 1)
		else
			return uri

	#
	# Return true if everything after the last '/' slash matches for two strings
	#
	@lastUriSegmentMatch : (a, b) ->
		return Utils.lastUriSegment(a) is Utils.lastUriSegment(b)

	@literalValueMatch : (a, b) ->
		if (typeof a is 'undefined') or (typeof b is 'undefined')
			return false
		if typeof a is 'object' or typeof b is 'object'
			return false
		a = @literalValue a
		b = @literalValue b
		return false if not (a and b)
		return a is b

	@literalValue: (str) ->
		return if typeof str is 'undefined'
		if str[0] isnt '"'
			return str
		if N3Util.isLiteral(str)
			return N3Util.getLiteralValue(str)

	@isNumber: (str) ->
		return IsNumber(str)

	@isDate: (str) ->
		return /^\d\d\d\d-/.test str

	@withoutContext : (def) ->
		out = {}
		for k, v of def
			if k.match(Utils.INTERNAL_FIELD_REGEX.match) or k.match(Utils.CONTEXT_FIELD_REGEX)
				continue
			out[k] = {}
			for kk, vv of v
				if k.match(Utils.INTERNAL_FIELD_REGEX.match) or k.match(Utils.CONTEXT_FIELD_REGEX)
					continue
				out[k][kk] = vv
		return out

	@isJoinMulti : (def) ->
		typeof(def) is 'object' and
		def.type and
		Array.isArray(def.type) and
		def.type[0] and
		typeof def.type[0] is 'object' and
		def.type[0].ref and
		def.type[0].type

	@isJoinSingle : (def) ->
		return typeof(def) is 'object' and
			not(Array.isArray def) and
			def.ref and
			def.type

	@dumplog: (obj) ->
		console.log @dump obj

	@dump: (obj) ->
		Inspect obj, {
			depth: 8
			showHidden: false
			colors: true
		}


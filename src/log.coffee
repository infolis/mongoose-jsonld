Winston = require('winston')
Winston.emitErrs = true
Chalk = require 'chalk'
Util = require 'util'

module.exports = (callingModule) ->

	getLabel = ->
		parts = callingModule.filename.split('/')
		# return parts[parts.length - 2] + '/' + parts.pop()
		return parts.pop()
	getDate = ->
		tzoffset = (new Date).getTimezoneOffset() * 60000
		return new Date(Date.now() - tzoffset).toISOString().substring(11,23)
	getMeta = (obj) ->
		if not obj or (not obj.name and Object.keys(obj).length == 0)
			return ''
		else
			msg = Util.inspect(obj, { colors: true })
			if /\n/.test(msg)
				return ">\n" + msg.replace(/^/mg, "  ")
			return msg

	formatter = (options) ->
		level = Winston.config.colorize(options.level, options.level.toUpperCase())
		timestamp = Chalk.yellow getDate()
		label = Chalk.magenta getLabel()
		meta = getMeta(options.meta)
		message = options.message
		return "#{timestamp} [#{level}] #{label}: #{message} #{meta}"
	logger = new Winston.Logger
		transports: [
			new Winston.transports.File
				level: 'debug'
				filename: './logs/infolis-web.log'
				handleExceptions: true
				json: true
				maxsize: 5242880
				maxFiles: 10
				colorize: false
			new Winston.transports.Console
				level: 'debug'
				handleExceptions: no
				json: false
				colorize: true
				formatter: formatter
		]
		exitOnError: false
	# logger.extend console
	# log = console.log
	# console.log = (level) ->
	#     if arguments.length > 1 and level of this
	#         log.apply this, arguments
	#     else
	#         args = Array::slice.call(arguments)
	#         args.unshift 'debug'
	#         log.apply this, args
	return logger

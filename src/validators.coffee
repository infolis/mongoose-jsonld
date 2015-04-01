buildValidator = (regex, msg) -> [
	# console.log regex.toString()
	(val) -> return regex.test(val)
	msg
]

module.exports  = {
	'validateURI':       buildValidator(/^https?:\/\/[^\s]+$/,                               "Not a valid URI")
	'validateMD5':       buildValidator(/^[a-f0-9]{32}$/,                                    "Not a valid MD5")
	'validateJavaClass': buildValidator(/^([a-zA-Z_][a-zA-Z\d_]*\.)*[a-zA-Z_][a-zA-Z\d_]*$/, "Not a valid fully-qualified java path")
}


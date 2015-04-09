validators = {}
_validators =
	URI:       /^https?:\/\/[^\s]+$/
	UUID:      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
	MD5:       /^[a-f0-9]{32}$/
	SHA1:       /^[a-f0-9]{40}$/
	JavaClass: [ /^([a-zA-Z_][a-zA-Z\d_]*\.)*[a-zA-Z_][a-zA-Z\d_]*$/, "Not a valid fully-qualified java path" ]

for type, v of _validators
	if Array.isArray(v)
		fn = (val) -> v[0].test(val)
		msg = v[1]
	else
		fn = v.test.bind(v)
		msg = "Not a valid #{type}"
	validators[type] = [fn, msg]

module.exports  = validators

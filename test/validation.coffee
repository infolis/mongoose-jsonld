test = require 'tapes'
validators = require '../src/validators'

allTests = {
	validateJavaClass: [
		['foo.bar']
		['foo.b/a@@@@r..', 'weird chars']
		['foo.b.',         'trailing dot']
	]
	validateURI: [
		['http://google.com']
		['https://foobar.quux']
		['http://foo bar', 'space']
	]
	validateMD5: [
		['00000000000000000000000000000000']
		['1237nfdkjewnfkjewnfewjkfewnewfew', 'wrong chars']
		['1237nfdkjewnfkjewnfewjkfewnfkjewnfkewfew', '40 chars']
	]
}

test "All the things", (t) ->
	for validator, tests of allTests
		for [str, reason] in tests
			if reason
				t.notOk validators[validator][0](str), "#{validator} doesn't match '#{str}' because '#{reason}'"
			else
				t.ok validators[validator][0](str), "#{validator} matches '#{str}'"
	t.end()

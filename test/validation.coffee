test = require 'tapes'
validators = require '../src/validators'
console.log validators

allTests = {
	JavaClass: [
		['foo.bar']
		['foo.b/a@@@@r..', 'weird chars']
		['foo.b.',         'trailing dot']
	]
	URI: [
		['http://google.com']
		['https://foobar.quux']
		['http://foo bar', 'space']
	]
	MD5: [
		['00000000000000000000000000000000']
		['1237nfdkjewnfkjewnfewjkfewnewfew', 'wrong chars']
		['1237nfdkjewnfkjewnfewjkfewnfkjewnfkewfew', '40 chars']
	]
	UUID: [
		['63ce13a3-6c87-4608-865f-cbf12fef3ee9']
		['63ce13a3-6c87-4608-865f-cbf12fef3ee', 'too short']
		['63ce13a3-6c87-4608-865f-cbf12fef3ee99', 'too long']
		['63ce13a3-6c87-4608-865f-Ybf12fef3ee9', 'bad alpha chars']
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

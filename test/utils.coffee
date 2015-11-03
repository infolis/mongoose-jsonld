Utils = require '../src/utils'
test     = require 'tape'

test 'isJoinSingle', (t) ->
	t.notOk Utils.isJoinSingle()  , "no (null)"
	t.notOk Utils.isJoinSingle(42), "no (42)"
	t.notOk Utils.isJoinSingle({}), "no (empty object)"
	t.notOk Utils.isJoinSingle([]), "no (empty array)"
	t.notOk Utils.isJoinSingle({typex: String, ref: 'User'}), "no (typo typex/type)"
	t.ok Utils.isJoinSingle({type: String, ref: 'User'}), "yay"
	t.end()

test 'isJoinMulti', (t) ->
	t.notOk Utils.isJoinMulti()  , "no (null)"
	t.notOk Utils.isJoinMulti(42), "no (42)"
	t.notOk Utils.isJoinMulti({}), "no (empty object)"
	t.notOk Utils.isJoinMulti([]), "no (empty array)"
	t.notOk Utils.isJoinMulti({type: String, ref: 'User'}), "no (single join)"
	t.ok Utils.isJoinMulti([{type: String, ref: 'User'}]), "yes (on type)"
	t.end()

test 'lastUriSegment', (t) ->
	t.equals Utils.lastUriSegment('http://'), ''
	t.equals Utils.lastUriSegment('http://foo'), 'foo'
	t.equals Utils.lastUriSegment('http://foo/bar'), 'bar'
	t.end()

test 'lcfirst', (t) ->
	t.equals Utils.lcfirst('FooBar'), 'fooBar'
	t.end()

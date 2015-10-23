Utils = require '../src/utils'
test     = require 'tape'

test 'isJoinSingle', (t) ->
	t.notOk Utils.isJoinSingle()
	t.notOk Utils.isJoinSingle(42)
	t.notOk Utils.isJoinSingle({})
	t.notOk Utils.isJoinSingle([])
	t.notOk Utils.isJoinSingle({typex: String, ref: 'User'})
	t.ok Utils.isJoinSingle({type: String, ref: 'User'})
	t.end()

test 'isJoinMulti', (t) ->
	t.notOk Utils.isJoinMulti()
	t.notOk Utils.isJoinMulti(42)
	t.notOk Utils.isJoinMulti({})
	t.notOk Utils.isJoinMulti([])
	t.notOk Utils.isJoinMulti({type: String, ref: 'User'})
	t.ok Utils.isJoinMulti(type: [{type: String, ref: 'User'}])
	t.notOk Utils.isJoinMulti([{type: String, ref: 'User'}])
	t.end()

test 'lastUriSegment', (t) ->
	t.equals Utils.lastUriSegment('http://'), ''
	t.equals Utils.lastUriSegment('http://foo'), 'foo'
	t.equals Utils.lastUriSegment('http://foo/bar'), 'bar'
	t.end()

test 'lcfirst', (t) ->
	t.equals Utils.lcfirst('FooBar'), 'fooBar'
	t.end()

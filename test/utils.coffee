Utils = require '../src/utils'
test     = require 'tape'

test 'lastUriSegment', (t) ->
	t.equals Utils.lastUriSegment('http://'), ''
	t.equals Utils.lastUriSegment('http://foo'), 'foo'
	t.equals Utils.lastUriSegment('http://foo/bar'), 'bar'
	t.equals Utils.lastUriSegment('http://foo/bar#quux'), 'quux'
	t.ok Utils.lastUriSegmentMatch('http://foo/bar#quux', 'quux')
	t.end()

test 'literals', (t) ->
	t.equals Utils.literalValue(undefined), undefined
	t.notOk Utils.literalValueMatch(undefined, null)
	t.notOk Utils.literalValueMatch(null, null)
	t.ok Utils.literalValueMatch('1', '1')
	t.ok Utils.literalValueMatch('"1"', '1')
	t.false Utils.literalValueMatch('"1"', undefined)
	t.end()

test 'lcfirst', (t) ->
	t.equals Utils.lcfirst('FooBar'), 'fooBar'
	t.end()

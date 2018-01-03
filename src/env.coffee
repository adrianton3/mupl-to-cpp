'use strict'


add = (items...) ->
	make items, @


has = (item) ->
	@items.has item or @parent.has item


proto = { add, has }


make = (items, parent) ->
	instance = Object.create proto
	Object.assign instance, {
		items: new Set items
		parent
	}


empty = {
	add: (items...) -> make items, empty
	has: -> false
}

Object.freeze empty


global = if typeof module != "undefined" and module.exports then module.exports else window

global.muplToCpp ?= {}
Object.assign global.muplToCpp, {
	env: { empty }
}
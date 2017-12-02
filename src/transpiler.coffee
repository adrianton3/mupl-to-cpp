'use strict'


transpilers = {
	'number': ({ value }) ->
		"makeValue(#{value})"

	'if': ({ test, alternate, consequent }) ->
		"(#{transpile test}) ? (#{transpile consequent}) : (#{transpile alternate})"

	'let': ({ name, body, expression }) ->
		"""
			[&](auto #{name}){
				return #{transpile body};
			}(#{transpile expression})
		"""

	'var': ({ name }) ->
		name

	'lambda': ({ parameter, body }) ->
			"""
				makeValue([=](auto #{parameter}) {
					return #{transpile body};
				})
			"""

	'call': ({ callee, argument }) ->
			"makeValue(#{transpile callee})->call(#{transpile argument})"

	'+': ({ terms }) ->
		transpiled = terms.map (term) -> "#{transpile term}->getNumber()"
		"makeValue(#{transpiled.join ' + '})"


	'-': ({ left, right }) ->
			"""
				(makeValue(#{transpile left}->getNumber() - #{transpile right}->getNumber()))
			"""

	'pair': ({ first, second }) ->
			"""
				makeValue(#{transpile first}, #{transpile second})
			"""

	'first': ({ expression }) ->
			"""
				#{transpile expression}->getFirst()
			"""

	'second': ({ expression }) ->
			"""
				#{transpile expression}->getSecond()
			"""
}


transpile = (node) ->
	transpilers[node.type] node


transpileRoot = (node) ->
	"""
		#include <iostream>
		#include "../../../src/env/value.h"

		int main() {
			ValuePtr result = #{transpile node};
			std::cout << result->serialize();
			return 0;
		}
	"""


global = if typeof module != "undefined" and module.exports then module.exports else window

global.muplToCpp ?= {}
Object.assign global.muplToCpp, {
	transpile: transpileRoot,
}

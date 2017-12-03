'use strict'


makeOperator = (operator) ->
	({ terms }) ->
		transpiled = terms.map (term) -> "#{transpile term}->getNumber()"
		"makeValue(#{transpiled.join " #{operator} "})"


transpilers = {
	'number': ({ value }) ->
		"makeValue(#{value})"

	'if': ({ test, alternate, consequent }) ->
		"(#{transpile test}) ? (#{transpile consequent}) : (#{transpile alternate})"

	'let': ({ bindings, body }) ->
		declarations = bindings.map ({ name, expression }) ->
			"const auto #{name} = #{transpile expression};"

		"""
			[&]{
				#{declarations.join '\n'}
				return #{transpile body};
			}()
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

	'+': makeOperator '+'
	'-': makeOperator '-'
	'*': makeOperator '*'

	'null': -> 'Null'

	'null?': ({ expression }) ->
		"makeValue(#{transpile expression}->isNull())"

	'pair': ({ first, second }) ->
		"makeValue(#{transpile first}, #{transpile second})"

	'first': ({ expression }) ->
		"#{transpile expression}->getFirst()"

	'second': ({ expression }) ->
		"#{transpile expression}->getSecond()"
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

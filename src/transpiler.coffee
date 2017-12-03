'use strict'


makeOperator = (operator) ->
	({ terms }) ->
		transpiled = terms.map (term) -> "#{transpile term}->getNumber()"
		"makeValue(#{transpiled.join " #{operator} "})"


transpilers = {
	'number': ({ value }) ->
		"makeValue(#{value})"

	'if': ({ test, alternate, consequent }) ->
		"(#{transpile test}->getBoolean()) ? (#{transpile consequent}) : (#{transpile alternate})"

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

	'fun': ({ name, parameter, body }) ->
		"""
			[&]{
				ValuePtr #{name} = makeValue([](ValuePtr) { return null; });
				const auto _fun = [=](auto #{parameter}) {
					return #{transpile body};
				};

				static_cast<Function&>(*#{name}).set(_fun);
				return #{name};
			}()
		"""

	'call': ({ callee, argument }) ->
		"#{transpile callee}->call(#{transpile argument})"

	'+': makeOperator '+'
	'-': makeOperator '-'
	'*': makeOperator '*'

	'<': ({ left, right }) ->
		"makeBoolean(#{transpile left}->getNumber() < #{transpile right}->getNumber())"

	'null': -> 'Null'

	'null?': ({ expression }) ->
		"makeBoolean(#{transpile expression}->isNull())"

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

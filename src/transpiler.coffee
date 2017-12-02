'use strict'


transpile = (node) ->
	switch node.type
		when 'number'
			"makeValue(#{node.value})"

		when 'if'
			"(#{transpile node.test}) ? (#{transpile node.consequent}) : (#{transpile node.alternate})"

		when 'let'
			"""
				[&](auto #{node.name}){
					return #{transpile node.body};
				}(#{transpile node.expression})
			"""

		when 'var'
			node.name

		when 'lambda'
			"""
				makeValue([=](auto #{node.parameter}) {
					return #{transpile node.body};
				})
			"""

		when 'call'
			"makeValue(#{transpile node.callee})->call(#{transpile node.argument})"

		when '+'
			"""
				(makeValue(#{transpile node.left}->getNumber() + #{transpile node.right}->getNumber()))
			"""

		when '-'
			"""
				(makeValue(#{transpile node.left}->getNumber() - #{transpile node.right}->getNumber()))
			"""

		when 'pair'
			"""
				makeValue(#{transpile node.first}, #{transpile node.second})
			"""

		when 'first'
			"""
				#{transpile node.expression}->getFirst()
			"""

		when 'second'
			"""
				#{transpile node.expression}->getSecond()
			"""


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

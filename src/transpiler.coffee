'use strict'


{ muplToCpp: { env } } = if typeof module != "undefined" and module.exports
	require './env'
else
	window


builtIns = new Set [
	'+'
	'-'
	'*'
	'<'
]


transpileBuiltIn = (name, args, env, options) ->
	switch name
		when '+', '-', '*', '<'
			transpile { type: name, terms: args }, env, options
		else
			throw ''


tryUnwrap = (conversion, matchingNodes) ->
	(node, env) ->
		if (matchingNodes.includes node.type) or ((node.type == 'call') and (node.callee.type == 'var') and (builtIns.has node.callee.name) and not (env.has node.callee.name))
			transpile node, env, { raw: true }
		else
			"#{transpile node, env}->#{conversion}()"
			
			
toNumber = tryUnwrap 'getNumber', ['number', '+', '-', '*']


toBoolean = tryUnwrap 'getBoolean', ['boolean', '<', 'null?']


makeOperator = (operator) ->
	({ terms }, env, { raw }) ->
		transpiled = terms.map (term) -> toNumber term, env

		if raw
			"(#{transpiled.join " #{operator} "})"
		else
			"makeValue(#{transpiled.join " #{operator} "})"


transpilers = {
	'number': ({ value }, env, { raw }) ->
		if raw
			"#{value}"
		else
			"makeValue(#{value})"

	'if': ({ test, alternate, consequent }, env) ->
		"(#{toBoolean test, env}) ? (#{transpile consequent, env}) : (#{transpile alternate, env})"

	'let': ({ bindings, body }, env) ->
		declarations = bindings.map ({ name, expression }) ->
			"const auto #{name} = #{transpile expression, env};"

		newEnv = env.add (bindings.map ({ name }) -> name)...

		"""
			[&]{
				#{declarations.join '\n'}
				return #{transpile body, newEnv};
			}()
		"""

	'var': ({ name }) ->
		name

	'lambda': ({ parameters, body }, env) ->
		step = (prev, parameter) ->
			"""
				makeValue([=](auto #{parameter}) {
					return #{prev};
				})
			"""

		newEnv = env.add parameters...
		parameters.reduceRight step, (transpile body, newEnv)

	'fun': ({ name, parameters, body }, env) ->
		step = (prev, parameter) ->
			"""
				makeValue([=](auto #{parameter}) {
					return #{prev};
				})
			"""

		newEnv = env.add name, parameters...
		rest = (parameters.slice 1).reduceRight step, (transpile body, newEnv)

		"""
			[&]{
				ValuePtr #{name} = makeValue([](ValuePtr) { return null; });
				const auto _fun = [=](auto #{parameters[0]}) {
					return #{rest};
				};
				static_cast<Function&>(*#{name}).set(_fun);
				return #{name};
			}()
		"""

	'call': ({ callee, args }, env, options) ->
		if (callee.type == 'var') and (builtIns.has callee.name) and not (env.has callee.name)
			transpileBuiltIn callee.name, args, env, options
		else
			callChain = args.map (arg) -> "->call(#{transpile arg, env})"
			"#{transpile callee, env}#{callChain.join ''}"

	'+': makeOperator '+'

	'-': makeOperator '-'

	'*': makeOperator '*'

	'<': ({ terms: [left, right] }, env, { raw }) ->
		if raw
			"(#{toNumber left, env} < #{toNumber right, env})"
		else
			"makeBoolean(#{toNumber left, env} < #{toNumber right, env})"

	'null': -> 'Null'

	'null?': ({ expression }, env, { raw }) ->
		if raw
			"#{transpile expression, env}->isNull()"
		else
			"makeBoolean(#{transpile expression, env}->isNull())"

	'pair': ({ first, second }, env) ->
		"makeValue(#{transpile first, env}, #{transpile second, env})"

	'first': ({ expression }, env) ->
		"#{transpile expression, env}->getFirst()"

	'second': ({ expression }, env) ->
		"#{transpile expression, env}->getSecond()"
}


transpile = (node, env, options = {}) ->
	transpilers[node.type] node, env, options


transpileRoot = (node) ->
	"""
		#include <iostream>
		#include "../../../src/cpp-env/value.h"

		int main() {
			ValuePtr result = #{transpile node, env.empty};
			std::cout << result->serialize();
			return 0;
		}
	"""


global = if typeof module != "undefined" and module.exports then module.exports else window

global.muplToCpp ?= {}
Object.assign global.muplToCpp, {
	transpile: transpileRoot,
}

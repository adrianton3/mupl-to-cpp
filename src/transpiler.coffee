'use strict'


{ muplToCpp: { env } } = if typeof module != "undefined" and module.exports
	require './env'
else
	window

{ muplToCpp: { encodeIdentifier } } = if typeof module != "undefined" and module.exports
	require './safe-identifiers'
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


toBoolean = tryUnwrap 'getBoolean', ['boolean', '<', '>', 'null?']


makeOperator = (operator) ->
	({ terms }, env, { raw }) ->
		transpiled = terms.map (term) -> toNumber term, env

		if raw
			"(#{transpiled.join " #{operator} "})"
		else
			"makeValue(#{transpiled.join " #{operator} "})"


makeRelational = (operator) ->
	({ terms }, env, { raw }) ->
		nonVars = []
		transpiled = []

		begin = 1
		end = terms.length - 1

		transpiled.push toNumber terms[0], env

		for index in [begin...end]
			term = terms[index]
			transpiled.push(
				if term.type in ['var', 'number', 'boolean']
					toNumber term, env
				else
					nonVars.push { index, term }
					"_term_#{index}"
			)

		transpiled.push toNumber terms[terms.length - 1], env


		comparisons = [transpiled[0]]

		for i in [begin...end]
			comparisons.push "#{operator} #{transpiled[i]} && #{transpiled[i]}"

		comparisons.push "#{operator} #{transpiled[transpiled.length - 1]}"

		expression = if nonVars.length == 0
				comparisons.join ' '
			else
				declarations = nonVars.map ({ index, term }) ->
						"const auto _term_#{index} = #{toNumber term, env};"

				"""
					[&]{
						#{declarations.join '\n'}
						return #{comparisons.join ' '};
					}()
				"""

		if raw
			"(#{expression})"
		else
			"makeBoolean(#{expression})"


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
			"const auto #{encodeIdentifier name} = #{transpile expression, env};"

		newEnv = env.add (bindings.map ({ name }) -> name)...

		"""
			[&]{
				#{declarations.join '\n'}
				return #{transpile body, newEnv};
			}()
		"""

	'var': ({ name }) ->
		encodeIdentifier name

	'lambda': ({ parameters, body }, env) ->
		step = (prev, parameter) ->
			"""
				makeValue([=](auto #{encodeIdentifier parameter}) {
					return #{prev};
				})
			"""

		newEnv = env.add parameters...
		parameters.reduceRight step, (transpile body, newEnv)

	'fun': ({ name, parameters, body }, env) ->
		step = (prev, parameter) ->
			"""
				makeValue([=](auto #{encodeIdentifier parameter}) {
					return #{prev};
				})
			"""

		newEnv = env.add name, parameters...
		rest = (parameters.slice 1).reduceRight step, (transpile body, newEnv)

		"""
			[&]{
				ValuePtr #{encodeIdentifier name} = makeValue([](ValuePtr) { return null; });
				const auto _fun = [=](auto #{encodeIdentifier parameters[0]}) {
					return #{rest};
				};
				static_cast<Function&>(*#{encodeIdentifier name}).set(_fun);
				return #{encodeIdentifier name};
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

	'<': makeRelational '<'

	'>': makeRelational '>'

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

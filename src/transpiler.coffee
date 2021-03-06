'use strict'


{ muplToCpp: { env } } = if typeof module != "undefined" and module.exports
	require './env'
else
	window

{ muplToCpp: { encodeIdentifier } } = if typeof module != "undefined" and module.exports
	require './safe-identifiers'
else
	window


builtIns = new Map [
	['+', { returnType: 'number' }]
	['-', { returnType: 'number' }]
	['*', { returnType: 'number' }]
	['<', { returnType: 'boolean' }]
	['>', { returnType: 'boolean' }]
	['null?', { returnType: 'boolean' }]
	['number?', { returnType: 'boolean' }]
	['boolean?', { returnType: 'boolean' }]
	['pair?', { returnType: 'boolean' }]
	['function?', { returnType: 'boolean' }]
	['pair', { returnType: 'any' }]
	['first', { returnType: 'any' }]
	['second', { returnType: 'any' }]
]


transpileBuiltIn = (name, args, env, options) ->
	switch name
		when '+', '-', '*', '<', '>'
			transpile { type: name, terms: args }, env, options
		when 'null?', 'number?', 'boolean?', 'pair?', 'function?'
			transpile { type: name, expression: args[0] }, env, options
		when 'pair'
			transpile { type: name, first: args[0], second: args[1] }, env, options
		when 'first', 'second'
			transpile { type: name, expression: args[0] }, env, options
		else
			throw "can not transpile as built-in #{name}"


tryUnwrap = (conversion, matchingNodes, returnType) ->
	(node, env) ->
		if (matchingNodes.includes node.type) or
			(
				(node.type == 'call') and
				(node.callee.type == 'var') and
				(builtIns.has node.callee.name) and
				not (env.has node.callee.name) and
				(builtIns.get node.callee.name).returnType == returnType
			)
			transpile node, env, { raw: true }
		else
			"#{transpile node, env}->#{conversion}()"
			
			
toNumber = tryUnwrap 'getNumber', ['number', '+', '-', '*'], 'number'


toBoolean = tryUnwrap 'getBoolean', ['boolean', '<', '>', 'null?', 'number?', 'boolean?', 'pair?', 'function?'], 'boolean'


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


makeTypeChecker = (checker) ->
	({ expression }, env, { raw }) ->
		check = "#{transpile expression, env}->#{checker}()"

		if raw
			check
		else
			"makeBoolean(#{check})"


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
		step = (prev, parameter, index) ->
			partials = (parameters.slice 0, index)
				.map (parameter) -> ",#{parameter}"
				.join ' '

			"""
				makeValue([& #{partials}](auto #{encodeIdentifier parameter}) {
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

	'null?': makeTypeChecker 'isNull'

	'number?': makeTypeChecker 'isNumber'

	'boolean?': makeTypeChecker 'isBoolean'

	'pair?': makeTypeChecker 'isPair'

	'function?': makeTypeChecker 'isFunction'

	'pair': ({ first, second }, env) ->
		"makeValue(#{transpile first, env}, #{transpile second, env})"

	'first': ({ expression }, env) ->
		"#{transpile expression, env}->getFirst()"

	'second': ({ expression }, env) ->
		"#{transpile expression, env}->getSecond()"

	'def': ({ name, expression }, env) ->
		"#{encodeIdentifier name} = #{transpile expression, env};"
}


transpile = (node, env, options = {}) ->
	if transpilers[node.type]?
		transpilers[node.type] node, env, options
	else
		throw "can not transpile node of type #{node.type}"


transpileProgram = (program) ->
	topEnv = env.empty.add (program.defs.map ({ name }) -> name)...

	defsTranspiled = program.defs.map (def) -> transpile def, topEnv

	declarations = program.defs.map ({ name }) -> encodeIdentifier name

	"""
		#include <iostream>
		#include "../../../src/cpp-env/value.h"

		int main() {
			ValueMutPtr #{declarations.join ', '};
			#{defsTranspiled.join '\n'}
			ValuePtr result = #{transpile program.expression, topEnv};
			std::cout << result->serialize();
			return 0;
		}
	"""


transpileExpression = (expression) ->
	"""
		#include <iostream>
		#include "../../../src/cpp-env/value.h"

		int main() {
			ValuePtr result = #{transpile expression, env.empty};
			std::cout << result->serialize();
			return 0;
		}
	"""


transpileRoot = (node) ->
	if node.type == 'program'
		transpileProgram node
	else
		transpileExpression node


global = if typeof module != "undefined" and module.exports then module.exports else window

global.muplToCpp ?= {}
Object.assign global.muplToCpp, {
	transpile: transpileRoot,
}

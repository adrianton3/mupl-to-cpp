(function () {
	'use strict';

	var subs = {
		'if': 3,
		'let': 2,
		'lambda': 2,
		'pair': 2,
		'first': 1,
		'second': 1,
	};

	function makeNode(type, properties) {
		return function () {
			var node = {
				type: type
			};
			var args = arguments;
			properties.forEach(function (property, index) {
				node[property] = args[index];
			});
			return node;
		}
	}

	var $call = makeNode('call', ['callee', 'argument']);
	var $lambda = makeNode('lambda', ['parameter', 'body']);
	var $fun = makeNode('fun', ['name', 'parameter', 'body']);
	var $let = makeNode('let', ['name', 'expression', 'body']);
	var $if = makeNode('if', ['test', 'consequent', 'alternate']);
	var $var = makeNode('var', ['name']);
	var $number = makeNode('number', ['value']);
	var $less = makeNode('<', ['left', 'right']);
	var $pair = makeNode('pair', ['first', 'second']);
	var $first = makeNode('first', ['expression']);
	var $second = makeNode('second', ['expression']);

	function buildCall(call) {
		// (callee x y z)
		return {
			type: 'call',
			callee: buildAst(call.children[0]),
			args: call.children.slice(1).map(buildAst),
		}
	}

	function buildLambda(lambda) {
		// (lambda (x y z) body)
		if (lambda.children[1].type !== 'list') {
			throw new Error('missing parameter list for anonymous function')
		}

		const parameters = lambda.children[1].children

		parameters.forEach((parameter) => {
			if (parameter.type !== 'atom' || parameter.token.type != 'identifier') {
				throw new Error('formal parameters must be alphanums')
			}
		})

		return {
			type: 'lambda',
			parameters: parameters.map((parameter) => parameter.token.value),
			body: buildAst(lambda.children[2]),
		}
	}

	function buildFun(fun) {
		// (fun f (x y z) body)
		if (fun.children[1].type !== 'atom' || fun.children[1].token.type !== 'identifier') {
			throw new Error('function name must be an alphanum')
		}

		const parameters = fun.children[2].children

		parameters.forEach((parameter) => {
			if (parameter.type !== 'atom' || parameter.token.type != 'identifier') {
				throw new Error('formal parameters must be alphanums')
			}
		})

		return {
			type: 'fun',
			name: fun.children[1].token.value,
			parameters: parameters.map((parameter) => parameter.token.value),
			body: buildAst(fun.children[3]),
		}
	}

	function buildLet({ children }) {
		// (let ((x 123) (y 456)) 789)
		if (children[1].token.type !== 'open') {
			throw new Error('missing binding list for let expression')
		}

		const bindings = children[1].children

		if (bindings.length < 1) {
			throw new Error('binding list must contain at least 1 binding')
		}

		bindings.forEach((pair) => {
			if (pair.token.type !== 'open') {
				throw new Error('binding list items are pairs of an identifier and an expression')
			}

			if (pair.children.length !== 2) {
				throw new Error('binding list items must have 2 members, an identifier and an expression')
			}

			if (pair.children[0].token.type !== 'identifier') {
				throw new Error('cannot bind to non-identifiers')
			}
		})

		return {
			type: 'let',
			bindings: bindings.map(({ children }) => ({
				name: children[0].token.value,
				expression: buildAst(children[1]),
			})),
			body: buildAst(children[2]),
		}
	}

	function buildOperator({ children }) {
		if (children.length < 3) {
			throw new Error('math operator takes at least 2 arguments')
		}

		const terms = []

		for (let i = 1; i < children.length; i++) {
			terms.push(buildAst(children[i]))
		}

		return {
			// hack, removes the $
			type: children[0].token.value.slice(1),
			terms,
		}
	}

	function buildList({ children }) {
		let list = $var('null')
		for (let i = children.length - 1; i > 0; i--) {
			list = $pair(buildAst(children[i]), list)
		}

		return list
	}

	function buildAst(tree) {
		switch (tree.token.type) {
			case 'number':
				return $number(tree.token.value);
			case 'identifier':
				return $var(tree.token.value);
			case 'open':
				if (!tree.children.length) {
					throw new Error('Unexpected empty ()');
				}
				if (tree.children[0].token.type === 'identifier') {
					var formType = tree.children[0].token.value;
					if (subs[formType] !== undefined) {
						if (subs[formType] !== tree.children.length - 1) {
							throw new Error(formType + ' special form admits ' + subs[formType] + ' parameters');
						}
					}
				}

				switch (formType) {
					case 'if':
						return $if(
							buildAst(tree.children[1]),
							buildAst(tree.children[2]),
							buildAst(tree.children[3])
						);
					// used for debugging only
					case '$+':
					case '$-':
					case '$*':
					case '$<':
						return buildOperator(tree)
					// used for debugging only
					case '$pair':
						return $pair(
							buildAst(tree.children[1]),
							buildAst(tree.children[2])
						);
					case '$list':
						return buildList(tree)
					case '$null?':
						return {
							type: 'null?',
							expression: buildAst(tree.children[1]),
						}
					// used for debugging only
					case '$first':
						return $first(
							buildAst(tree.children[1])
						);
					// used for debugging only
					case '$second':
						return $second(
							buildAst(tree.children[1])
						);
					case 'let':
						return buildLet(tree);
					case 'lambda':
						return buildLambda(tree);
					case 'fun':
						return buildFun(tree);
					default:
						return buildCall(tree);
				}
			default:
				console.warn(`Token type ${tree.token.type} not supported`);
		}
	}

	const global = typeof module !== "undefined" && module.exports ? module.exports : window

	if (!global.muplToCpp) { global.muplToCpp = {}; }
	Object.assign(global.muplToCpp, {
		buildAst,
		buildNode: {
			$call,
			$lambda,
			$fun,
			$let,
			$if,
			$var,
			$number,
		}
	})
})();
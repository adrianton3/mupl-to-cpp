(function () {
	'use strict';

	var subs = {
		'$+': 2,
		'$-': 2,
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
	var $add = makeNode('+', ['left', 'right']);
	var $sub = makeNode('-', ['left', 'right']);
	var $var = makeNode('var', ['name']);
	var $number = makeNode('number', ['value']);
	var $pair = makeNode('pair', ['first', 'second']);
	var $first = makeNode('first', ['expression']);
	var $second = makeNode('second', ['expression']);

	function buildCall(call) {
		// (call (call (call callee x) y) z)
		// (callee x y z)
		var ret = buildAst(call.children[0]);
		for (var i = 1; i < call.children.length; i++) {
			ret = $call(ret, buildAst(call.children[i]));
		}
		return ret;
	}

	function buildLambda(lambda) {
		// (lambda x (lambda y (lambda z body)))
		// (lambda (x y z) body)
		if (lambda.children[1].token.type !== '(') {
			throw new Error('missing parameter list for anonymous function');
		}

		var params = lambda.children[1].children;
		var ret = buildAst(lambda.children[2]);
		for (var i = params.length - 1; i >= 0; i--) {
			if (params[i].token.type !== 'identifier') {
				throw new Error('formal parameters must be alphanums');
			}

			ret = $lambda(params[i].token.value, ret);
		}
		return ret;
	}

	function buildFun(fun) {
		// (fun f x (lambda y (lambda z body)))
		// (fun f (x y z) body)
		if (fun.children[1].token.type !== 'identifier') {
			throw new Error('function name must be an alphanum');
		}

		if (fun.children[2].token.type !== '(') {
			throw new Error('missing parameter list for function');
		}

		var params = fun.children[2].children;
		var ret = buildAst(fun.children[3]);
		for (var i = params.length - 1; i >= 1; i--) {
			if (params[i].token.type !== 'identifier') {
				throw new Error('formal parameters must be alphanums');
			}

			ret = $lambda(params[i].token.value, ret);
		}

		return $fun(
			fun.children[1].token.value,
			params[i].token.value,
			ret
		);
	}

	function buildLet(let_) {
		// (let x 123 (let y 456 789))
		// (let ((x 123) (y 456)) 789)
		if (let_.children[1].token.type !== '(') {
			throw new Error('missing binding list for let expression');
		}

		var list = let_.children[1].children;

		if (list.length < 1) {
			throw new Error('binding list must contain at least 1 binding');
		}

		list.forEach(function (pair) {
			if (pair.token.type !== '(') {
				throw new Error('binding list items are pairs of an identifier and an expression');
			}

			if (pair.children.length !== 2) {
				throw new Error('binding list items must have 2 members, an identifier and an expression');
			}

			if (pair.children[0].token.type !== 'identifier') {
				throw new Error('cannot bind to non-identifiers');
			}
		});

		var ret = buildAst(let_.children[2]);
		for (var i = list.length - 1; i >= 0; i--) {
			var pair = list[i];
			ret = $let(
				pair.children[0].token.value,
				buildAst(pair.children[1]),
				ret
			);
		}

		return ret;
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
					case '$+': // used for debugging only
						return $add(
							buildAst(tree.children[1]),
							buildAst(tree.children[2])
						);
					case '$-': // used for debugging only
						return $sub(
							buildAst(tree.children[1]),
							buildAst(tree.children[2])
						);
					case '$pair': // used for debugging only
						return $pair(
							buildAst(tree.children[1]),
							buildAst(tree.children[2])
						);
					case '$first': // used for debugging only
						return $first(
							buildAst(tree.children[1])
						);
					case '$second': // used for debugging only
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
			$add,
			$sub,
			$var,
			$number,
		}
	})
})();
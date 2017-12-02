'use strict'

const fs = require('fs')
const { Tokenizer, Parser } = require('../../lib/espace.min')
const { buildAst } = require('../../src/build-ast').muplToCpp
const { transpile } = require('../../src/transpiler').muplToCpp


function run (source) {
	if (!source || source.length === 0) {
		return null
	}

	const tokens = Tokenizer.tokenize(source)
	const tree = Parser.parse(tokens)
	const ast = buildAst(tree)

	return transpile(ast)
}

if (require.main === module) {
	// get arg, figure out if it's a file or a path
	// if invalid path try parse
	// if valid path try parse
	// if both are valid find file
	// if both are valid and file is there throw

	const sourceOrFile = process.argv[2]

	// just check for a ( as the first char for now
	if (sourceOrFile[0] === '(') {
		const transpiled = run(sourceOrFile)
		process.stdout.write(transpiled)
	} else {
		const source = fs.readFileSync(sourceOrFile, 'utf8')
		const transpiled = run(source)
		process.stdout.write(transpiled)
	}
}
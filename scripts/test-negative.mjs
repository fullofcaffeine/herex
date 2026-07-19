import {spawnSync} from "node:child_process";
import process from "node:process";

const fixtures = [
	["UnknownAttribute", "unknown attribute \"mystery\"", 3],
	["DuplicateAttribute", "duplicate attribute \"mode\"", 3],
	["DynamicAttribute", "attribute \"newlines\" requires a non-negative integer literal", 4],
	["InvalidMode", "invalid mode \"surprising\"", 3],
	["MissingMargin", "nonblank margin line must begin with \"|\"", 5],
	["ConflictingOptions", "\"margin\" and \"mode\" cannot be combined", 3],
	["InvalidEscape", "invalid Haxe escape sequence \\q", 3],
	["ContradictoryInterpolation", "\"reindent\" is only valid when interpolation is enabled", 3],
	["InvalidNewlineCount", "attribute \"newlines\" requires a non-negative integer literal", 3],
	["UnclosedInterpolation", "unclosed interpolation brace", 3],
];

let failed = false;
for (const [name, expected, line] of fixtures) {
	const result = spawnSync(
		"haxe",
		["-cp", "src", "-cp", "test/negative", "--macro", "herex.HeredocSyntax.use()", "-main", name, "--no-output"],
		{encoding: "utf8"},
	);
	const output = `${result.stdout ?? ""}${result.stderr ?? ""}`;
	const location = `test/negative/${name}.hx:${line}:`;
	if (result.status === 0 || !output.includes(`Herex: ${expected}`) || !output.includes(location)) {
		failed = true;
		process.stderr.write(`\n[negative] ${name} did not fail as expected\n${output}\n`);
	}
}

const invalidAlias = spawnSync(
	"haxe",
	["-cp", "src", "-cp", "test/src", "-D", "herex_alias=1bad", "--macro", "herex.HeredocSyntax.use()", "-main", "AliasMain", "--no-output"],
	{encoding: "utf8"},
);
const invalidAliasOutput = `${invalidAlias.stdout ?? ""}${invalidAlias.stderr ?? ""}`;
if (invalidAlias.status === 0 || !invalidAliasOutput.includes("Herex: -D herex_alias requires a tag name")) {
	failed = true;
	process.stderr.write(`\n[negative] invalid project alias did not fail as expected\n${invalidAliasOutput}\n`);
}

if (failed) {
	process.exit(1);
}
process.stdout.write(`Herex negative fixtures passed: ${fixtures.length} syntax fixtures and 1 project configuration\n`);

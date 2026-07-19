import {spawnSync} from "node:child_process";
import {mkdirSync, rmSync} from "node:fs";
import path from "node:path";
import process from "node:process";

const outputDirectory = path.resolve("out", "targets");
rmSync(outputDirectory, {recursive: true, force: true});
mkdirSync(outputDirectory, {recursive: true});

const common = [
	"-cp",
	"src",
	"-cp",
	"test/src",
	"--macro",
	"herex.HeredocSyntax.use()",
	"--macro",
	"DummySyntax.use()",
	"-main",
	"TestMain",
];

const targets = [
	{
		name: "javascript",
		compile: [...common, "-js", path.join(outputDirectory, "test.js")],
		run: [process.execPath, path.join(outputDirectory, "test.js")],
	},
	{
		name: "neko",
		compile: [...common, "-neko", path.join(outputDirectory, "test.n")],
		run: ["neko", path.join(outputDirectory, "test.n")],
	},
	{
		name: "python",
		compile: [...common, "-python", path.join(outputDirectory, "test.py")],
		run: [process.platform === "win32" ? "python" : "python3", path.join(outputDirectory, "test.py")],
	},
];

for (const target of targets) {
	run("haxe", target.compile, `compile ${target.name}`);
	run(target.run[0], target.run.slice(1), `run ${target.name}`);
}

process.stdout.write(`Herex cross-target suites passed: ${targets.length}\n`);

function run(command, args, label) {
	const result = spawnSync(command, args, {encoding: "utf8"});
	process.stdout.write(result.stdout ?? "");
	process.stderr.write(result.stderr ?? "");
	if (result.status !== 0) {
		throw new Error(`${label} failed with exit code ${result.status}`);
	}
}

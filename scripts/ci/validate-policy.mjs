import {spawnSync} from "node:child_process";
import {readdirSync, readFileSync} from "node:fs";
import path from "node:path";
import process from "node:process";

const workflows = [
	read(".github/workflows/ci.yml"),
	read(".github/workflows/release.yml"),
	read(".github/workflows/release-repair.yml"),
];
const workflowText = workflows.join("\n");
const uses = [...workflowText.matchAll(/uses:\s*[^@\s]+@([^\s#]+)/g)].map((match) => match[1]);
requireCondition(uses.length > 0 && uses.every((reference) => /^[0-9a-f]{40}$/.test(reference)), "Every GitHub Action must use a full commit SHA");
requireIncludes(workflows[0], "contents: read", "CI must default to read-only repository permissions");
requireIncludes(workflows[1], "contents: write", "Release must declare its narrowly scoped write permission");
requireIncludes(workflows[1], "github.ref == 'refs/heads/main'", "Manual releases must also be restricted to main");
requireIncludes(workflows[2], "environment: release-repair", "Repair must require its protected environment");
requireCondition(!workflowText.includes("haxelib submit"), "Workflows must never publish to the Haxelib registry");

const semanticVerification = read("scripts/release/semantic-verify.mjs");
requireIncludes(semanticVerification, '"x-github-api-version": "2026-03-10"', "Release verification must request the immutable-release API schema");
requireIncludes(semanticVerification, "candidate.immutable !== true", "Release verification must wait for GitHub immutability");

const metadata = JSON.parse(read("haxelib.json"));
requireCondition(metadata.version === "0.0.0", "Source haxelib metadata must stay at development version 0.0.0");
requireCondition(metadata.classPath === "src", "The release class path must be src");
requireCondition(Object.keys(metadata.dependencies).length === 0, "Herex must remain dependency-free");
requireCondition(read("extraParams.hxml").trim() === "--macro herex.HeredocSyntax.use()", "-lib herex must auto-register the syntax hook");
requireIncludes(read("haxe_libraries/formatter.hxml"), "formatter#1.18.0", "The formatter lock must remain exact");

const readme = read("README.md");
requireIncludes(readme, "releases/download/v1.0.1/herex-1.0.1.zip", "README must lead with the first installable versioned GitHub Release asset");
requireIncludes(readme, "-lib herex", "README must document one-line project activation");
requireIncludes(readme, "<hd", "README must document the compact built-in alias");
requireIncludes(read("AGENTS.example.md"), "Do not mechanically convert", "Agent guidance must preserve the heredoc/concatenation balance");

const releaseConfiguration = read("release.config.mjs");
requireIncludes(releaseConfiguration, 'path: "artifacts/herex-*.zip"', "GitHub release assets must use glob paths supported by the publisher");
requireCondition(!releaseConfiguration.includes('path: "artifacts/herex-${'), "GitHub release asset paths must not contain uninterpreted templates");

for (const file of walk("scripts").filter((name) => name.endsWith(".mjs"))) {
	const result = spawnSync(process.execPath, ["--check", file], {encoding: "utf8"});
	if (result.status !== 0) {
		throw new Error(`JavaScript syntax check failed for ${file}:\n${result.stderr}`);
	}
}

process.stdout.write(`Release and repository policy checks passed; ${uses.length} Action references are SHA-pinned\n`);

function read(name) {
	return readFileSync(name, "utf8");
}

function walk(directory) {
	const results = [];
	for (const entry of readdirSync(directory, {withFileTypes: true})) {
		const name = path.join(directory, entry.name);
		if (entry.isDirectory()) {
			results.push(...walk(name));
		} else if (entry.isFile()) {
			results.push(name);
		}
	}
	return results;
}

function requireIncludes(value, expected, message) {
	requireCondition(value.includes(expected), message);
}

function requireCondition(condition, message) {
	if (!condition) {
		throw new Error(message);
	}
}

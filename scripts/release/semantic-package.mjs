import {execFileSync} from "node:child_process";
import {readdirSync, rmSync} from "node:fs";
import process from "node:process";

export async function verifyConditions(_pluginConfig, context) {
	const head = git("rev-parse", "HEAD");
	if (context.branch.name !== "main") {
		throw new Error(`Releases are restricted to main, received ${context.branch.name}`);
	}
	if (process.env.GITHUB_SHA && process.env.GITHUB_SHA !== head) {
		throw new Error(`Checked-out commit ${head} does not match GITHUB_SHA ${process.env.GITHUB_SHA}`);
	}
}

export async function prepare(_pluginConfig, context) {
	const version = context.nextRelease.version;
	const head = git("rev-parse", "HEAD");
	if (context.nextRelease.gitHead !== head) {
		throw new Error(`semantic-release selected ${context.nextRelease.gitHead}, but the checked-out commit is ${head}`);
	}
	rmSync("artifacts", {recursive: true, force: true});
	run(process.execPath, ["scripts/release/package.mjs", "--version", version, "--output", "artifacts"]);
	run(process.execPath, ["scripts/release/verify-package.mjs", `artifacts/herex-${version}.zip`, version]);
	run(process.execPath, ["scripts/release/lix-consumer-smoke.mjs", `artifacts/herex-${version}.zip`, version]);
	const expected = [`herex-${version}.zip`, `herex-${version}.zip.sha256`];
	const actual = readdirSync("artifacts").sort();
	if (actual.join("\n") !== expected.sort().join("\n")) {
		throw new Error(`Release artifact directory must contain exactly ${expected.join(", ")}; received ${actual.join(", ")}`);
	}
}

function git(...args) {
	return execFileSync("git", args, {encoding: "utf8"}).trim();
}

function run(command, args) {
	execFileSync(command, args, {stdio: "inherit"});
}

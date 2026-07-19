import {createHash} from "node:crypto";
import {execFileSync} from "node:child_process";
import {lstatSync, readFileSync} from "node:fs";
import path from "node:path";
import {strToU8, unzipSync, zipSync} from "fflate";
import semver from "semver";

const fixedTime = new Date(1980, 0, 1, 0, 0, 0);
const rootFiles = [
	"AGENTS.example.md",
	"CONTRIBUTING.md",
	"LICENSE",
	"README.md",
	"RELEASING.md",
	"SECURITY.md",
	"extraParams.hxml",
];

export function buildArchive(version) {
	if (!semver.valid(version)) {
		throw new Error(`Invalid release version: ${version}`);
	}

	const commit = execFileSync("git", ["rev-parse", "HEAD"], {encoding: "utf8"}).trim();
	const packagePaths = [...rootFiles, "haxelib.json", "assets", "src"];
	const trackedFiles = listTrackedFiles(packagePaths);
	for (const required of [...rootFiles, "haxelib.json"]) {
		if (!trackedFiles.includes(required)) {
			throw new Error(`Release input must be tracked by Git: ${required}`);
		}
	}
	assertCleanPackageInputs(packagePaths);

	const entries = new Map();
	for (const file of trackedFiles) {
		if (file !== "haxelib.json") {
			entries.set(file, readRegularFile(file));
		}
	}

	const metadata = JSON.parse(readFileSync("haxelib.json", "utf8"));
	metadata.version = version;
	metadata.releasenote = `Herex ${version}`;
	entries.set("haxelib.json", strToU8(`${JSON.stringify(metadata, null, "\t")}\n`));
	entries.set(
		"release.json",
		strToU8(
			`${JSON.stringify(
				{
					name: "herex",
					version,
					commit,
					source: `https://github.com/fullofcaffeine/herex/tree/${commit}`,
				},
				null,
				"\t",
			)}\n`,
		),
	);

	const zippable = {};
	for (const [name, bytes] of [...entries].sort(([left], [right]) => left.localeCompare(right))) {
		validateArchivePath(name);
		zippable[name] = [bytes, {mtime: fixedTime, os: 3, attrs: 0o644 << 16, level: 9}];
	}
	const archive = zipSync(zippable, {level: 9, mtime: fixedTime, os: 3});
	return {archive, commit, entries: [...entries.keys()].sort()};
}

export function verifyArchive(archive, version) {
	const files = unzipSync(archive);
	const names = Object.keys(files).sort();
	for (const name of names) {
		validateArchivePath(name);
	}

	const required = ["extraParams.hxml", "haxelib.json", "README.md", "LICENSE", "release.json", "src/herex/HeredocSyntax.hx"];
	for (const name of required) {
		if (!files[name]) {
			throw new Error(`Release archive is missing ${name}`);
		}
	}
	if (names.some((name) => name.startsWith("test/") || name.startsWith("scripts/") || name.startsWith("node_modules/"))) {
		throw new Error("Release archive contains development-only files");
	}

	const metadata = JSON.parse(Buffer.from(files["haxelib.json"]).toString("utf8"));
	if (metadata.name !== "herex" || metadata.version !== version || metadata.classPath !== "src") {
		throw new Error("Release haxelib.json does not match the requested Herex version and class path");
	}
	if (Object.keys(metadata.dependencies ?? {}).length !== 0) {
		throw new Error("Herex release unexpectedly declares dependencies");
	}

	const extraParameters = Buffer.from(files["extraParams.hxml"]).toString("utf8");
	if (extraParameters.trim() !== "--macro herex.HeredocSyntax.use()") {
		throw new Error("Release does not enable the expected automatic Herex syntax hook");
	}
	const release = JSON.parse(Buffer.from(files["release.json"]).toString("utf8"));
	if (release.version !== version || !/^[0-9a-f]{40}$/.test(release.commit)) {
		throw new Error("Release provenance metadata is invalid");
	}
	return {files: names, metadata, release};
}

export function sha256(bytes) {
	return createHash("sha256").update(bytes).digest("hex");
}

function listTrackedFiles(paths) {
	return execFileSync("git", ["ls-files", "-z", "--", ...paths], {encoding: "utf8"})
		.split("\0")
		.filter((name) => name.length > 0)
		.sort();
}

function assertCleanPackageInputs(paths) {
	const status = execFileSync("git", ["status", "--porcelain=v1", "--untracked-files=all", "--", ...paths], {encoding: "utf8"}).trim();
	if (status.length > 0) {
		throw new Error(`Release inputs must exactly match tracked files at HEAD:\n${status}`);
	}
}

function readRegularFile(name) {
	const details = lstatSync(name);
	if (!details.isFile() || details.isSymbolicLink()) {
		throw new Error(`Release input must be a regular file: ${name}`);
	}
	if (name === "LICENSE" || [".hx", ".hxml", ".json", ".md"].includes(path.extname(name))) {
		return strToU8(readFileSync(name, "utf8").replace(/\r\n?/g, "\n"));
	}
	return new Uint8Array(readFileSync(name));
}

function validateArchivePath(name) {
	if (name.startsWith("/") || name.includes("\\") || name.split("/").includes("..")) {
		throw new Error(`Unsafe release archive path: ${name}`);
	}
}

import {mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync} from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import {buildArchive, sha256, verifyArchive} from "./package-lib.mjs";

const versionIndex = process.argv.indexOf("--version");
const version = versionIndex === -1 ? process.env.HEREX_RELEASE_VERSION : process.argv[versionIndex + 1];
if (!version) {
	throw new Error("Pass --version <semver> or set HEREX_RELEASE_VERSION");
}

const outputIndex = process.argv.indexOf("--output");
const outputDirectory = path.resolve(outputIndex === -1 ? "artifacts" : process.argv[outputIndex + 1]);
const temporaryDirectory = mkdtempSync(path.join(os.tmpdir(), "herex-package-"));

try {
	const first = buildArchive(version);
	const second = buildArchive(version);
	if (!Buffer.from(first.archive).equals(Buffer.from(second.archive))) {
		throw new Error("Two release builds from the same source produced different bytes");
	}
	verifyArchive(first.archive, version);

	mkdirSync(outputDirectory, {recursive: true});
	const archiveName = `herex-${version}.zip`;
	const archivePath = path.join(outputDirectory, archiveName);
	const checksumPath = `${archivePath}.sha256`;
	writeFileSync(path.join(temporaryDirectory, archiveName), first.archive);
	const copied = readFileSync(path.join(temporaryDirectory, archiveName));
	writeFileSync(archivePath, copied);
	writeFileSync(checksumPath, `${sha256(copied)}  ${archiveName}\n`);
	process.stdout.write(`${archivePath}\n${checksumPath}\n`);
} finally {
	rmSync(temporaryDirectory, {recursive: true, force: true});
}

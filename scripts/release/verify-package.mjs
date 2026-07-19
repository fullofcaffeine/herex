import {readFileSync} from "node:fs";
import path from "node:path";
import process from "node:process";
import {sha256, verifyArchive} from "./package-lib.mjs";

const [archiveArgument, version] = process.argv.slice(2);
if (!archiveArgument || !version) {
	throw new Error("Usage: node verify-package.mjs <archive.zip> <version>");
}

const archivePath = path.resolve(archiveArgument);
const archive = readFileSync(archivePath);
const result = verifyArchive(archive, version);
const checksum = readFileSync(`${archivePath}.sha256`, "utf8").trim();
const expected = `${sha256(archive)}  ${path.basename(archivePath)}`;
if (checksum !== expected) {
	throw new Error(`Checksum file mismatch: expected ${expected}`);
}
process.stdout.write(`Verified Herex ${version}: ${result.files.length} files, ${sha256(archive)}\n`);

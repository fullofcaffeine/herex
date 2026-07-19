import {rmSync, writeFileSync} from "node:fs";
import {buildArchive} from "./release/package-lib.mjs";

const probe = "src/.herex-untracked-package-probe";
writeFileSync(probe, "must not enter a release archive\n", {flag: "wx"});
try {
	try {
		buildArchive("1.0.0");
		throw new Error("Release packaging accepted an untracked source file");
	} catch (error) {
		if (!String(error.message).includes(probe)) {
			throw error;
		}
	}
} finally {
	rmSync(probe, {force: true});
}

process.stdout.write("Release packaging rejects untracked package inputs\n");

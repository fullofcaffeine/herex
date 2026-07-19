import {spawnSync} from "node:child_process";
import {mkdtempSync, rmSync, writeFileSync} from "node:fs";
import os from "node:os";
import path from "node:path";

const directory = mkdtempSync(path.join(os.tmpdir(), "herex-crlf-"));
try {
	const source = [
		"class CrLfMain {",
		"\tstatic function main():Void {",
		"\t\tvar value = <heredoc>",
		"\t\t\tfirst",
		"\t\t\tsecond",
		"\t\t</heredoc>;",
		"\t\tif (value != \"first\\nsecond\") throw \"CRLF normalization failed\";",
		"\t\ttrace(\"Herex CRLF source passed\");",
		"\t}",
		"}",
		"",
	].join("\r\n");
	writeFileSync(path.join(directory, "CrLfMain.hx"), source);
	const result = spawnSync(
		"haxe",
		["-cp", "src", "-cp", directory, "--macro", "herex.HeredocSyntax.use()", "-main", "CrLfMain", "--interp"],
		{encoding: "utf8"},
	);
	process.stdout.write(result.stdout ?? "");
	process.stderr.write(result.stderr ?? "");
	if (result.status !== 0) {
		throw new Error(`CRLF source fixture failed with exit code ${result.status}`);
	}
} finally {
	rmSync(directory, {recursive: true, force: true});
}

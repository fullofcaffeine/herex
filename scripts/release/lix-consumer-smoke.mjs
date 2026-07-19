import {spawn} from "node:child_process";
import {createServer} from "node:http";
import {mkdtempSync, readFileSync, rmSync, writeFileSync} from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";

const [sourceArgument, version] = process.argv.slice(2);
if (!sourceArgument || !version) {
	throw new Error("Usage: node lix-consumer-smoke.mjs <archive.zip|https-url> <version>");
}

const publicUrl = sourceArgument.startsWith("https://") ? sourceArgument : null;
const archivePath = publicUrl == null ? path.resolve(sourceArgument) : null;
const archive = archivePath == null ? null : readFileSync(archivePath);
const temporaryDirectory = mkdtempSync(path.join(os.tmpdir(), "herex-lix-consumer-"));
const lixEntry = path.resolve("node_modules", "lix", "bin", "lix.js");
const haxeEntry = path.resolve("node_modules", "lix", "bin", "haxeshim.js");
const server = createServer((request, response) => {
	if (archive == null || request.url !== `/herex-${version}.zip`) {
		response.writeHead(404).end();
		return;
	}
	response.writeHead(200, {"content-type": "application/zip", "content-length": archive.length});
	response.end(archive);
});

try {
	writeFileSync(
		path.join(temporaryDirectory, ".haxerc"),
		`${JSON.stringify({version: "4.3.7", resolveLibs: "scoped"}, null, "\t")}\n`,
	);
	writeFileSync(
		path.join(temporaryDirectory, "Main.hx"),
		`class Main {
\tstatic function main():Void {
\t\tvar who = "Lix";
\t\tvar generated = <heredoc newline>
\t\t\tinstalled with $who
\t\t\tAssigns<T> stays text and 1 < 2
\t\t</heredoc>;
\t\tvar expected = "installed with Lix\\nAssigns<T> stays text and 1 < 2\\n";
\t\tif (generated != expected) throw "Herex consumer mismatch";
\t\ttrace("Herex Lix consumer passed");
\t}
}
`,
	);
	writeFileSync(path.join(temporaryDirectory, "build.hxml"), "-lib herex\n-main Main\n--interp\n");
	const localPortPatch = path.join(temporaryDirectory, "lix-local-port.cjs");
	writeFileSync(
		localPortPatch,
		`const http = require("node:http");
const originalGet = http.get;
http.get = function patchedGet(options, ...rest) {
  if (options && typeof options === "object" && typeof options.host === "string") {
    const local = /^(127\\.0\\.0\\.1):(\\d+)$/.exec(options.host);
    if (local) {
      options = {...options, hostname: local[1], port: Number(local[2])};
      delete options.host;
    }
  }
  return originalGet.call(this, options, ...rest);
};
`,
	);

	var url = publicUrl;
	var installEnvironment = process.env;
	if (url == null) {
		await new Promise((resolve, reject) => {
			server.once("error", reject);
			server.listen(0, "127.0.0.1", resolve);
		});
		const address = server.address();
		if (typeof address === "string" || address == null) {
			throw new Error("Could not determine local package server port");
		}
		url = `http://127.0.0.1:${address.port}/herex-${version}.zip`;
		// Lix 17's bundled URL adapter passes host:port as a DNS hostname. This
		// narrow preload only routes the local pre-publish smoke server; public
		// GitHub Release URLs use normal HTTPS and do not need the workaround.
		installEnvironment = {
			...process.env,
			NODE_OPTIONS: `${process.env.NODE_OPTIONS ?? ""} --require=${localPortPatch}`.trim(),
		};
	}
	const installUrl = lixInstallUrl(url);
	await run(process.execPath, [lixEntry, "install", installUrl], temporaryDirectory, installEnvironment);
	await run(process.execPath, [lixEntry, "download"], temporaryDirectory);
	await run(process.execPath, [haxeEntry, "build.hxml"], temporaryDirectory);
	process.stdout.write(`Lix installed and compiled ${archivePath == null ? installUrl : path.basename(archivePath)} using only -lib herex\n`);
} finally {
	if (server.listening) {
		await new Promise((resolve) => server.close(resolve));
	}
	rmSync(temporaryDirectory, {recursive: true, force: true});
}

function lixInstallUrl(url) {
	const parsed = new URL(url);
	// Lix 17 case-sensitively intercepts bare github.com URLs as repository
	// sources before its generic HTTPS resolver. Release asset paths then fail
	// that repository parser. GitHub's www host serves the same immutable asset.
	if (parsed.protocol === "https:" && parsed.hostname === "github.com") {
		parsed.hostname = "www.github.com";
	}
	return parsed.toString();
}

function run(command, args, cwd, env = process.env) {
	return new Promise((resolve, reject) => {
		const child = spawn(command, args, {cwd, env, stdio: "inherit"});
		child.once("error", reject);
		child.once("exit", (code) => {
			if (code === 0) {
				resolve();
			} else {
				reject(new Error(`${command} ${args.join(" ")} exited with ${code}`));
			}
		});
	});
}

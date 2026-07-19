import {createHash} from "node:crypto";
import {spawnSync} from "node:child_process";
import {chmodSync, existsSync, mkdirSync, readFileSync, writeFileSync} from "node:fs";
import path from "node:path";
import process from "node:process";
import {unzipSync} from "fflate";

const version = "8.30.1";
const releases = {
	"darwin-arm64": ["gitleaks_8.30.1_darwin_arm64.tar.gz", "b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5"],
	"darwin-x64": ["gitleaks_8.30.1_darwin_x64.tar.gz", "dfe101a4db2255fc85120ac7f3d25e4342c3c20cf749f2c20a18081af1952709"],
	"linux-arm64": ["gitleaks_8.30.1_linux_arm64.tar.gz", "e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080"],
	"linux-x64": ["gitleaks_8.30.1_linux_x64.tar.gz", "551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb"],
	"win32-arm64": ["gitleaks_8.30.1_windows_arm64.zip", "b95f5e4f5c425cedca7ee203d9afd29597e692c4924a12ed42f970537c72cc0f"],
	"win32-x64": ["gitleaks_8.30.1_windows_x64.zip", "d29144deff3a68aa93ced33dddf84b7fdc26070add4aa0f4513094c8332afc4e"],
};

const platform = `${process.platform}-${process.arch}`;
const release = releases[platform];
if (!release) {
	throw new Error(`No verified Gitleaks ${version} archive is configured for ${platform}`);
}

const [archiveName, expectedChecksum] = release;
const toolDirectory = path.resolve("out", "tools", `gitleaks-${version}-${platform}`);
const archivePath = path.join(toolDirectory, archiveName);
const executablePath = path.join(toolDirectory, process.platform === "win32" ? "gitleaks.exe" : "gitleaks");
mkdirSync(toolDirectory, {recursive: true});

if (!existsSync(archivePath)) {
	const url = `https://github.com/gitleaks/gitleaks/releases/download/v${version}/${archiveName}`;
	const response = await fetch(url);
	if (!response.ok) {
		throw new Error(`Could not download ${url}: HTTP ${response.status}`);
	}
	writeFileSync(archivePath, new Uint8Array(await response.arrayBuffer()));
}

const archive = readFileSync(archivePath);
const actualChecksum = createHash("sha256").update(archive).digest("hex");
if (actualChecksum !== expectedChecksum) {
	throw new Error(`Gitleaks archive checksum mismatch: expected ${expectedChecksum}, received ${actualChecksum}`);
}

if (!existsSync(executablePath)) {
	if (archiveName.endsWith(".zip")) {
		const files = unzipSync(archive);
		if (!files["gitleaks.exe"]) {
			throw new Error("Verified Gitleaks ZIP does not contain gitleaks.exe");
		}
		writeFileSync(executablePath, files["gitleaks.exe"]);
	} else {
		const extraction = spawnSync("tar", ["-xzf", archivePath, "-C", toolDirectory, "gitleaks"], {encoding: "utf8"});
		if (extraction.status !== 0) {
			throw new Error(`Could not extract Gitleaks: ${extraction.stderr}`);
		}
	}
	chmodSync(executablePath, 0o755);
}

const commitCount = spawnSync("git", ["rev-list", "--count", "--all"], {encoding: "utf8"});
if (commitCount.status !== 0 || Number.parseInt(commitCount.stdout, 10) < 1) {
	throw new Error(`Could not establish the Git history to scan: ${commitCount.stderr}`);
}
process.stdout.write(`Scanning ${commitCount.stdout.trim()} Git commits with verified Gitleaks ${version}\n`);
const result = spawnSync(
	executablePath,
	["git", "--redact", "--no-banner", "--config", ".gitleaks.toml", "--log-opts=--all", "."],
	{encoding: "utf8", stdio: "inherit"},
);
if (result.status !== 0) {
	process.exit(result.status ?? 1);
}
process.stdout.write(`Gitleaks ${version} verified and full Git history is clean\n`);

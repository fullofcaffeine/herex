import {createHash} from "node:crypto";
import {execFileSync, spawnSync} from "node:child_process";
import {readFileSync} from "node:fs";
import process from "node:process";
import semver from "semver";

const [tag] = process.argv.slice(2);
if (!tag || !tag.startsWith("v") || !semver.valid(tag.slice(1))) {
	throw new Error("Repair requires an existing semantic tag such as v1.2.3");
}
const version = tag.slice(1);
const repository = requiredEnvironment("GITHUB_REPOSITORY");
const token = process.env.GITHUB_TOKEN ?? process.env.GH_TOKEN;
if (!token) {
	throw new Error("GITHUB_TOKEN or GH_TOKEN is required");
}

const head = git("rev-parse", "HEAD");
const tagCommit = git("rev-list", "-n", "1", tag);
if (head !== tagCommit) {
	throw new Error(`Checked-out ${head} does not match protected ${tag} at ${tagCommit}`);
}

var release = await github(`/repos/${repository}/releases/tags/${tag}`, token);
if (!release.draft) {
	await verifyPublished(release);
	process.stdout.write(`${tag} is already published and verified; no repair was performed\n`);
	process.exit(0);
}

const expected = [`herex-${version}.zip`, `herex-${version}.zip.sha256`];
for (const name of expected) {
	const localPath = `artifacts/${name}`;
	const local = readFileSync(localPath);
	const existing = release.assets.find((asset) => asset.name === name);
	if (existing) {
		const remote = await downloadApiAsset(existing.url, token);
		if (!Buffer.from(remote).equals(local)) {
			throw new Error(`Draft asset ${name} differs from the verified build; repair will not replace it`);
		}
	} else {
		const upload = spawnSync("gh", ["release", "upload", tag, localPath], {encoding: "utf8", stdio: "inherit"});
		if (upload.status !== 0) {
			throw new Error(`Could not add missing draft asset ${name}`);
		}
	}
}

release = await github(`/repos/${repository}/releases/tags/${tag}`, token);
for (const name of expected) {
	if (!release.assets.some((asset) => asset.name === name)) {
		throw new Error(`Draft release still lacks ${name}`);
	}
}
await github(`/repos/${repository}/releases/${release.id}`, token, {method: "PATCH", body: JSON.stringify({draft: false})});
release = await retry(async () => {
	const candidate = await github(`/repos/${repository}/releases/tags/${tag}`, token);
	if (candidate.draft || candidate.immutable !== true) {
		throw new Error(`${tag} is not yet published and immutable`);
	}
	return candidate;
});
await verifyPublished(release);
process.stdout.write(`Repaired and verified existing draft ${tag}\n`);

async function verifyPublished(current) {
	if (current.draft || current.immutable !== true) {
		throw new Error(`${tag} is not a published immutable release`);
	}
	const archiveName = `herex-${version}.zip`;
	const archive = current.assets.find((asset) => asset.name === archiveName);
	const checksum = current.assets.find((asset) => asset.name === `${archiveName}.sha256`);
	if (!archive || !checksum) {
		throw new Error(`${tag} lacks its required assets`);
	}
	const archiveBytes = await retry(() => download(archive.browser_download_url));
	const checksumText = Buffer.from(await retry(() => download(checksum.browser_download_url))).toString("utf8");
	const digest = createHash("sha256").update(archiveBytes).digest("hex");
	if (!checksumText.startsWith(`${digest}  ${archiveName}`)) {
		throw new Error(`${tag} has an invalid asset checksum`);
	}
	await retry(async () => {
		execFileSync(process.execPath, ["scripts/release/lix-consumer-smoke.mjs", archive.browser_download_url, version], {stdio: "inherit"});
	});
}

async function github(endpoint, token, options = {}) {
	const response = await fetch(`https://api.github.com${endpoint}`, {
		...options,
		headers: {
			accept: "application/vnd.github+json",
			authorization: `Bearer ${token}`,
			"content-type": "application/json",
			"x-github-api-version": "2026-03-10",
			...(options.headers ?? {}),
		},
	});
	if (!response.ok) {
		throw new Error(`GitHub API ${endpoint} returned ${response.status}: ${await response.text()}`);
	}
	return response.status === 204 ? null : response.json();
}

async function downloadApiAsset(url, token) {
	const response = await fetch(url, {headers: {accept: "application/octet-stream", authorization: `Bearer ${token}`}});
	if (!response.ok) {
		throw new Error(`Could not download draft asset: HTTP ${response.status}`);
	}
	return new Uint8Array(await response.arrayBuffer());
}

async function download(url) {
	const response = await fetch(url);
	if (!response.ok) {
		throw new Error(`Could not download ${url}: HTTP ${response.status}`);
	}
	return new Uint8Array(await response.arrayBuffer());
}

function git(...args) {
	return execFileSync("git", args, {encoding: "utf8"}).trim();
}

function requiredEnvironment(name) {
	const value = process.env[name];
	if (!value) {
		throw new Error(`${name} is required`);
	}
	return value;
}

async function retry(operation) {
	var lastError;
	for (var attempt = 1; attempt <= 10; attempt++) {
		try {
			return await operation();
		} catch (error) {
			lastError = error;
			await new Promise((resolve) => setTimeout(resolve, attempt * 1000));
		}
	}
	throw lastError;
}

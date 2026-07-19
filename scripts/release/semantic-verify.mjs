import {createHash} from "node:crypto";
import {execFileSync} from "node:child_process";
import {readFileSync} from "node:fs";
import process from "node:process";

export async function success(_pluginConfig, context) {
	const version = context.nextRelease.version;
	const tag = `v${version}`;
	const repository = requiredEnvironment("GITHUB_REPOSITORY");
	const token = process.env.GITHUB_TOKEN ?? process.env.GH_TOKEN;
	if (!token) {
		throw new Error("GITHUB_TOKEN or GH_TOKEN is required for post-release verification");
	}

	const release = await retry(async () => {
		const candidate = await github(`/repos/${repository}/releases/tags/${tag}`, token);
		if (candidate.draft || candidate.tag_name !== tag || candidate.immutable !== true) {
			throw new Error(`GitHub Release ${tag} is not yet published and immutable`);
		}
		return candidate;
	});

	const reference = await github(`/repos/${repository}/git/ref/tags/${tag}`, token);
	if (reference.object.type !== "commit" || reference.object.sha !== context.nextRelease.gitHead) {
		throw new Error(`Protected tag ${tag} does not point to ${context.nextRelease.gitHead}`);
	}

	const archiveName = `herex-${version}.zip`;
	const checksumName = `${archiveName}.sha256`;
	const archiveAsset = release.assets.find((asset) => asset.name === archiveName);
	const checksumAsset = release.assets.find((asset) => asset.name === checksumName);
	if (!archiveAsset || !checksumAsset) {
		throw new Error(`GitHub Release ${tag} is missing its package or checksum asset`);
	}

	const [publishedArchive, publishedChecksum] = await Promise.all([
		retry(() => download(archiveAsset.browser_download_url)),
		retry(() => download(checksumAsset.browser_download_url)),
	]);
	const localArchive = readFileSync(`artifacts/${archiveName}`);
	const localChecksum = readFileSync(`artifacts/${checksumName}`);
	if (!Buffer.from(publishedArchive).equals(localArchive) || !Buffer.from(publishedChecksum).equals(localChecksum)) {
		throw new Error(`Published assets for ${tag} differ from the verified local artifacts`);
	}
	const digest = createHash("sha256").update(publishedArchive).digest("hex");
	if (!Buffer.from(publishedChecksum).toString("utf8").startsWith(`${digest}  ${archiveName}`)) {
		throw new Error(`Published checksum for ${tag} does not describe the published archive`);
	}

	await retry(async () => {
		execFileSync(process.execPath, ["scripts/release/lix-consumer-smoke.mjs", archiveAsset.browser_download_url, version], {stdio: "inherit"});
	});
	context.logger.log(`Verified immutable ${tag}, both release assets, and the public Lix installation URL`);
}

async function github(endpoint, token) {
	const response = await fetch(`https://api.github.com${endpoint}`, {
		headers: {accept: "application/vnd.github+json", authorization: `Bearer ${token}`, "x-github-api-version": "2026-03-10"},
	});
	if (!response.ok) {
		throw new Error(`GitHub API ${endpoint} returned ${response.status}: ${await response.text()}`);
	}
	return response.json();
}

async function download(url) {
	const response = await fetch(url);
	if (!response.ok) {
		throw new Error(`Could not download ${url}: HTTP ${response.status}`);
	}
	return new Uint8Array(await response.arrayBuffer());
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

function requiredEnvironment(name) {
	const value = process.env[name];
	if (!value) {
		throw new Error(`${name} is required`);
	}
	return value;
}

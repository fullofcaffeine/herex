export default {
	branches: ["main"],
	tagFormat: "v${version}",
	plugins: [
		["@semantic-release/commit-analyzer", {preset: "conventionalcommits"}],
		["@semantic-release/release-notes-generator", {preset: "conventionalcommits"}],
		"./scripts/release/semantic-package.mjs",
		[
			"@semantic-release/github",
			{
				assets: [
					{
						path: "artifacts/herex-*.zip",
						label: "Herex <%= nextRelease.version %> — Lix/Haxelib package",
					},
					{
						path: "artifacts/herex-*.zip.sha256",
						label: "SHA-256 checksum",
					},
				],
				releaseNameTemplate: "Herex v<%= nextRelease.version %>",
				successCommentCondition: false,
				failCommentCondition: false,
				labels: false,
				releasedLabels: false,
			},
		],
		"./scripts/release/semantic-verify.mjs",
	],
};

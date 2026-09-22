# Releasing LimitRoom

Official downloads and the Sparkle feed come from public [GitHub Releases](https://github.com/rvrhiv/LimitRoom/releases). The repository has one manual **Release** workflow. Pushes and pull requests do not start builds or publish anything; run local checks before merging.

## Publish from GitHub

1. Review the changes and privacy implications, run relevant [local checks](../CONTRIBUTING.md#verification), and merge to `main`. Optionally add `docs/releases/VERSION.md` for curated release notes; otherwise GitHub generates them.
2. Open [Actions → Release](https://github.com/rvrhiv/LimitRoom/actions/workflows/release.yml), select **Run workflow**, keep **main**, and enter only the new version, such as `0.7.0`. Use `MAJOR.MINOR.PATCH`, without a `v` prefix; it must be newer than the latest published release.
3. Wait for both jobs. The build job takes current `main` at checkout, freezes that commit, assigns the next build number, and runs source checks plus universal Dev and distribution builds without signing secrets. The protected publish job uses the same commit, prepares release notes, signs and verifies the artifacts, then publishes the release.
4. Check the successful run and the release's ZIP, `appcast.xml`, release notes, and `SHA256SUMS` asset listing. Separately validate update discovery, explicit installation, relaunch, and preservation of preferences/history from a previous installed version.

The workflow sets `CFBundleShortVersionString` from your input and `CFBundleVersion` to the last published Sparkle build number plus one. It stamps only the CI checkout: no version bump commit is pushed to `main`. The release tag identifies the source commit; the run log and appcast record the injected version and build. For a repository's first release, the build starts at 1. Missing or invalid existing metadata stops the run instead of restarting the counter.

The workflow creates the tag and release. **Do not create them in the Releases UI first.** Existing versions, tags, releases, and build numbers must not be reused. Only one official run can publish at a time. If `main` moves during the build, publication stops; start a new run after checking that no draft or tag was created.

If publication fails after creating a draft, inspect that draft and its assets before deciding how to recover. Do not blindly rerun the workflow or replace signed public assets. Old Actions runs remain available as history even when their workflow file has been removed.

## Signing authority

Before the first official run, configure:

- A GitHub Actions environment named `release`, restricted to the **branch `main`** only. Keep tags and wildcard refs out of this allowlist.
- Its environment secret `SPARKLE_PRIVATE_KEY`, containing the dedicated Sparkle Ed25519 seed. Keep the corresponding public verification key in the app.
- A secure recovery copy of the same private key in Keychain: service `https://sparkle-project.org`, account `com.rvrhiv.LimitRoom.release`.

The environment and branch restriction must exist before dispatch. Never generate a new signing key for each release or place private keys in source, logs, chat, or artifacts. Losing the signing key can break the update path; rotation needs a deliberate migration.

Trusted maintainers with repository write access can run the workflow without the owner's Mac or direct access to the secret. Permission to change trusted release workflows is effectively signing authority. Review those changes carefully; when adding maintainers, arrange branch protection and release approvals without depending on a single person's availability.

## Local preparation and recovery

Prefer the workflow for official releases. For authorized local preparation or recovery, use full Xcode and the dedicated Keychain entry. Set the desired version and a strictly increasing build in your local `Config/App-Info.plist`, and supply nonempty `docs/releases/VERSION.md` before running:

```sh
swift package resolve
bash Scripts/build-app.sh Release distribution
bash Scripts/package-release.sh VERSION BUILD
bash Scripts/sign-release.sh VERSION BUILD
```

Replace `VERSION` and `BUILD` with those local plist values. They may differ from the values committed in the tagged source because the workflow injects release metadata. The explicit `distribution` mode produces `build/LimitRoom.app` with release updates enabled; ordinary local builds produce `LimitRoom Dev.app` with updates disabled. Packaging rejects development builds and refuses to overwrite `build/releases/VERSION`; preserve earlier staging output before rebuilding. CI can generate missing notes between packaging and signing; local signing requires you to supply them.

Local signing uses Keychain by default. CI supplies the private key only to the signing step, which passes it to Sparkle through stdin, not a command-line argument or exported file. Build, package, and sign do not publish. `Scripts/publish-release.sh VERSION BUILD COMMIT` is a separate authorized action requiring authenticated GitHub CLI.

## Distribution limits

Current builds are ad-hoc signed, **not Apple Developer ID signed or notarized**. Sparkle signing establishes update integrity, not Apple first-install trust. Keep Gatekeeper and quarantine intact; notarization needs a separate distribution setup.

The app never embeds an owner's GitHub token. Update downloads are public, separate from agent credentials, and install only after user action. Versions without the updater need one manual installation of a current release.

For privacy checks and native acceptance, use [Contributing](../CONTRIBUTING.md#verification). The scripts and [.github/workflows/release.yml](../.github/workflows/release.yml) define the executable release procedure.

# Releasing LimitRoom

Official downloads and the Sparkle feed come from public [GitHub Releases](https://github.com/rvrhiv/LimitRoom/releases). A push runs **Build**, not **Release**. Publication is a separate manual action.

## Publish from GitHub

1. Update `CFBundleShortVersionString` and strictly increase `CFBundleVersion` in `Config/App-Info.plist`. Add matching `docs/releases/VERSION.md`.
2. Review the changes and privacy implications, merge to `main`, and wait for **Build** to pass.
3. Open [Actions → Release](https://github.com/rvrhiv/LimitRoom/actions/workflows/release.yml), select **Run workflow**, keep **main**, and enter the committed version and build number.
4. Wait for both jobs. The build job creates a universal app without signing secrets. The protected publish job signs and verifies the artifacts, creates a draft at that exact commit, uploads all assets, then publishes it.
5. Check the release ZIP, `appcast.xml`, release notes, and `SHA256SUMS`. From the previous installed version, verify discovery, explicit installation, relaunch, and preservation of preferences/history.

The workflow creates the tag and release. **Do not create them in the Releases UI first.** Existing versions, tags, releases, and build numbers must not be reused.

If publication fails after creating a draft, inspect that draft and its assets before deciding how to recover. Do not blindly rerun the workflow or replace signed public assets. No version-specific run recipe is kept here: the committed plist and release notes are the source of truth.

## Signing authority

Before the first official run, configure:

- A GitHub Actions environment named `release`, restricted to the **branch `main`** only. Keep tags and wildcard refs out of this allowlist.
- Its environment secret `SPARKLE_PRIVATE_KEY`, containing the dedicated Sparkle Ed25519 seed. Keep the corresponding public verification key in the app.
- A secure recovery copy of the same private key in Keychain: service `https://sparkle-project.org`, account `com.rvrhiv.LimitRoom.release`.

The environment and branch restriction must exist before dispatch. Never generate a new signing key for each release or place private keys in source, logs, chat, or artifacts. Losing the signing key can break the update path; rotation needs a deliberate migration.

Trusted maintainers with repository write access can run the workflow without the owner's Mac or direct access to the secret. Permission to change trusted release workflows is effectively signing authority. Review those changes carefully; when adding maintainers, arrange branch protection and release approvals without depending on a single person's availability.

## Local preparation and recovery

With full Xcode and the dedicated Keychain entry:

```sh
swift package resolve
bash Scripts/build-app.sh Release
bash Scripts/package-release.sh VERSION BUILD
bash Scripts/sign-release.sh VERSION BUILD
```

Replace `VERSION` and `BUILD` with the committed plist values. Packaging refuses to overwrite `build/releases/VERSION`; preserve earlier staging output before rebuilding.

Local signing uses Keychain by default. CI supplies the private key only to the signing step, which passes it to Sparkle through stdin, not a command-line argument or exported file. Build, package, and sign do not publish. `Scripts/publish-release.sh VERSION BUILD COMMIT` is a separate authorized action requiring authenticated GitHub CLI.

## Distribution limits

Current builds are ad-hoc signed, **not Apple Developer ID signed or notarized**. Sparkle signing establishes update integrity, not Apple first-install trust. Keep Gatekeeper and quarantine intact; notarization needs a separate distribution setup.

The app never embeds an owner's GitHub token. Update downloads are public, separate from agent credentials, and install only after user action. Versions without the updater need one manual installation of a current release.

For privacy checks and native acceptance, use [Contributing](../CONTRIBUTING.md#verification). The scripts and [.github/workflows/release.yml](../.github/workflows/release.yml) define the executable release procedure.

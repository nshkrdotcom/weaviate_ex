# Releasing weaviate_ex

## Step 1: Prepare for Release

1. Pull latest master:
   ```bash
   git checkout master
   git pull origin master
   ```

2. Determine next version (semantic versioning):
   - MAJOR: Breaking API changes
   - MINOR: New features, backwards compatible
   - PATCH: Bug fixes, backwards compatible

3. List merged PRs since last release:
   ```bash
   gh pr list --repo nshkrdotcom/weaviate_ex --state merged --search "merged:>=YYYY-MM-DD"
   ```

4. Update `CHANGELOG.md`:
   - Move items from `[Unreleased]` to new version section
   - Add release date

5. Update version in `mix.exs`:
   ```elixir
   @version "0.3.0"
   ```

6. Commit changes:
   ```bash
   git add CHANGELOG.md mix.exs
   git commit -m "chore: prepare release v0.3.0"
   git push origin master
   ```

## Step 2: Create Release

### Option 1: GitHub CLI

```bash
gh release create v0.3.0 --generate-notes --draft
```

### Option 2: Git + GitHub Web UI

1. Create and push tag:
   ```bash
   git tag -a v0.3.0 -m "v0.3.0"
   git push --tags
   ```

2. Create release from GitHub web UI

## Step 3: Monitor Pipeline

1. Check GitHub Actions workflow
2. When all tests pass:
   - Package is published to Hex.pm automatically
   - GitHub Release draft is created

3. Review and publish the GitHub Release draft

## Step 4: Post-Release

1. Announce release (if major):
   - Update README if needed
   - Post to relevant channels

2. Start next development cycle:
   - Add `[Unreleased]` section to CHANGELOG.md

## Hex.pm Publishing

Publishing is handled automatically by CI when a tag is pushed.

Requirements:
- `HEX_API_KEY` secret configured in GitHub
- All CI checks must pass

Manual publishing (if needed):
```bash
mix hex.publish
```

## Hotfix Releases

For urgent fixes to released versions:

1. Create hotfix branch from tag:
   ```bash
   git checkout -b hotfix/v0.3.1 v0.3.0
   ```

2. Apply fix, update version, update CHANGELOG

3. Merge to master and tag:
   ```bash
   git checkout master
   git merge hotfix/v0.3.1
   git tag -a v0.3.1 -m "v0.3.1"
   git push origin master --tags
   ```

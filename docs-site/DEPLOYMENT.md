# Deployment Guide

## Branch Strategy

- **main branch**: Triggers app releases (DMG/ZIP files) ONLY
- **dev branch**: For development work and documentation updates
- **gh-pages branch**: Auto-created by GitHub Actions for docs deployment

## How It Works

When you push documentation changes to the `dev` branch:
1. GitHub Actions builds the Jekyll site
2. Deploys it to the `gh-pages` branch
3. GitHub Pages serves it from `gh-pages` branch
4. No app release is triggered!

## GitHub Pages Setup

### First Time Setup:
1. Push to `dev` branch first (this creates the `gh-pages` branch)
2. Go to Settings → Pages in your GitHub repo
3. Under "Build and deployment":
   - Source: "Deploy from a branch"
   - Branch: `gh-pages` (select this instead of main)
   - Folder: `/ (root)`
4. Click Save

### DNS Setup (microverse.ashwch.com):
1. Go to your DNS provider for ashwch.com
2. Add a CNAME record:
   - Name: `microverse`
   - Value: `ashwch.github.io`
   - TTL: 3600 (or default)
3. Wait for DNS propagation (up to 24 hours)

## Workflow Summary

```bash
# For docs updates (NO app release):
git checkout dev
# make changes to docs-site/
git add .
git commit -m "docs: update site"
git push origin dev
# → Deploys docs only!

# For app releases (NO docs update):
git checkout main
# make app changes
git add .
git commit -m "fix: app bug"
git push origin main
# → Creates app release only!

# For both app and docs:
# First update docs on dev, then merge to main for app release
```

## Key Benefits

✅ Documentation updates don't trigger app releases
✅ App releases don't require documentation in the commit
✅ Clean separation of concerns
✅ Can update docs frequently without version bumps
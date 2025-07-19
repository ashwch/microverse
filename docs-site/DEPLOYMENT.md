# Deployment Guide

## Branch Strategy

- **main branch**: Triggers app releases (DMG/ZIP files)
- **dev branch**: For development work, updates docs but doesn't trigger releases

## GitHub Pages Setup

The docs site will automatically deploy when you push to either `main` or `dev` branches. The workflow is configured in `.github/workflows/docs.yml`.

## Subdomain Setup (microverse.ashwch.com)

### What GitHub Does Automatically:
1. The CNAME file in docs-site/ tells GitHub to serve the site at microverse.ashwch.com
2. GitHub will automatically handle SSL certificates

### What You Need to Do:
1. Go to your DNS provider for ashwch.com
2. Add a CNAME record:
   - Name: `microverse`
   - Value: `ashwch.github.io`
   - TTL: 3600 (or default)

### Enable GitHub Pages:
1. Go to Settings → Pages in your GitHub repo
2. Under "Build and deployment":
   - Source: GitHub Actions (this should be auto-selected after first deployment)
3. After DNS propagation (can take up to 24 hours), the site will be available at https://microverse.ashwch.com

## Workflow Summary

```bash
# For docs/site updates only:
git checkout dev
# make changes to docs-site/
git add .
git commit -m "docs: update site"
git push origin dev

# For app releases:
git checkout main
git merge dev  # if needed
git push origin main  # triggers release workflow
```

The docs will update on both branches, but app releases only happen on main.
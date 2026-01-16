# Website Deployment Guide

## Current Setup (Updated 2025)

### GitHub Pages Configuration
- **Source**: Main branch `/docs` folder
- **Custom Domain**: microverse.ashwch.com
- **Build**: Jekyll (automatic)
- **No separate gh-pages branch** - everything is in main/dev branches

## Branch Strategy

- **main branch**: Contains app code AND website files in `/docs` folder
  - Pushes to main always update the website (GitHub Pages serves from `main:/docs`)
  - App releases are cut by `.github/workflows/release.yml` on pushes to `main`, but **docs-only** pushes are ignored (see `paths-ignore`)
- Website files are in `/docs/` directory
- **dev branch**: For development work (app + docs)
  - No automatic deployment - changes must be merged to main

## Website Structure

```
/docs/                     # Website root (GitHub Pages source)
├── _config.yml           # Jekyll configuration
├── _layouts/default.html # Site layout template
├── index.md              # Homepage content
├── features.md           # Features page
├── download.md           # Download page
├── CNAME                 # Custom domain config
└── assets/               # CSS, images, etc.
    ├── css/main.css
    └── images/
```

## How to Update Website

### Method 1: Direct updates to main
```bash
git checkout main
# Edit files in docs/ folder
git add docs/
git commit -m "docs: update website content"
git push origin main
# → Updates website (docs-only pushes do NOT trigger an app release)
```

### Method 2: Update via dev branch (recommended)
```bash
git checkout dev
# Edit files in docs/ folder
git add docs/
git commit -m "docs: update website content"
git push origin dev

# Then create PR: dev → main
# Merge when ready to deploy docs (and/or app changes)
```

## DNS Configuration (microverse.ashwch.com)

DNS is already configured:
- CNAME record: `microverse.ashwch.com` → `ashwch.github.io`
- CNAME file in `/docs/CNAME` contains: `microverse.ashwch.com`

## Deployment Process

1. Changes pushed to main branch `/docs` folder
2. GitHub Pages automatically builds Jekyll site
3. Site deployed to https://microverse.ashwch.com
4. Usually takes 1-3 minutes to update

## Key Points

⚠️ **Important**: Pushing to main only triggers app releases when changes include non-ignored paths (not `docs/**`, workflows, etc.)
✅ Website files are versioned with the app in the same repository  
✅ Jekyll automatically processes markdown files in `/docs`
✅ No manual build steps required - GitHub handles everything

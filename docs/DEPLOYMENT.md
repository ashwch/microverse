# Website Deployment Guide

## Current Setup

- **Host**: Cloudflare Pages
- **Project**: `microverse`
- **Production branch**: `main`
- **Source**: `/docs`
- **Custom domain**: `microverse.ashwch.com`
- **Build**: Jekyll

GitHub Actions builds and directly uploads the site to Cloudflare Pages. Cloudflare's Git provider integration is not used.

## How to Update the Website

Make changes under `/docs` and merge them to `main`:

```bash
git checkout main
# Edit files in docs/
git add docs/
git commit -m "docs: update website content"
git push origin main
```

The `.github/workflows/cloudflare-pages.yml` workflow builds and deploys every `/docs` change on `main`.

App releases also update `docs/appcast.xml` and the release notes on `main`, then dispatch the same Cloudflare deployment workflow.

## Cloudflare Configuration

The `ashwch.com` zone and `microverse.ashwch.com` custom domain are managed in Cloudflare. The Pages custom-domain attachment owns the proxied DNS record, so this repository does not need a `CNAME` file.

GitHub repository settings used by the deployment workflow:

- Variable: `ASHWCH_COM_CLOUDFLARE_ACCOUNT_ID`
- Secret: `ASHWCH_COM_CLOUDFLARE_API_TOKEN`

The API token needs Cloudflare Pages edit access for the account.

## Deployment Process

1. A `/docs` change reaches `main`.
2. GitHub Actions builds the Jekyll site.
3. Wrangler uploads the generated site to the `microverse` Pages project.
4. Cloudflare serves it at <https://microverse.ashwch.com>.

Use the workflow's manual dispatch when a redeploy is needed without a content change.

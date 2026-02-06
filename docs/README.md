# Microverse Documentation Site

This is the source for the Microverse documentation site hosted at [microverse.ashwch.com](https://microverse.ashwch.com).

## Local Development

### Prerequisites

- Docker Desktop: [Download here](https://www.docker.com/products/docker-desktop)

### Running Locally

```bash
# Using Docker (recommended)
./serve-docker.sh
```

The site will be available at http://localhost:4000

### Alternative: Ruby-based setup

If you prefer to use Ruby directly:

```bash
# Install bundler if needed
gem install bundler

# Run the server
./serve.sh
```

## Deployment

The site is automatically deployed to GitHub Pages when changes are pushed to the repository. The CNAME file configures the custom domain `microverse.ashwch.com`.

## Structure

- `index.md` - Homepage
- `features.md` - Features showcase
- `download.md` - Download and installation instructions
- `PERFORMANCE.md` - Performance architecture and benchmark workflow
- `_layouts/` - Page templates
- `assets/` - CSS and images
- `_config.yml` - Jekyll configuration

## Design

The site follows the design system established at ashwch.com with:
- Light/dark theme support
- Responsive layout
- Clean, minimal aesthetic
- Consistent typography and spacing

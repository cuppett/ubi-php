# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This project builds enhanced PHP container images based on Red Hat UBI (Universal Base Image) and the SCL PHP image. The images include additional PHP extensions (igbinary, msgpack, redis) compiled from source to support Redis-based session handling and caching.

**Repository**: https://github.com/cuppett/ubi-php

## Architecture

### Container Image Variants

Four container images are built, each combining a UBI version with a PHP version:

- **UBI8 + PHP 7.4** (Containerfile.ubi8, BuildConfig: ubi8-php74)
- **UBI8 + PHP 8.0** (Containerfile.ubi8, BuildConfig: ubi8-php80)
- **UBI9 + PHP 8.0** (Containerfile.ubi9, BuildConfig: ubi9-php80)
- **UBI9 + PHP 8.1** (Containerfile.ubi9, BuildConfig: ubi9-php81)

### Build Configuration Structure

The project uses **Kustomize** for configuration management with two layers:

1. **Base Layer** (`build/openshift/`): Defines OpenShift ImageStream and BuildConfig resources for the `ubi-php` namespace
2. **Overlay Layer** (`build/cuppett/`): Applies patches to:
   - Change output destinations to push to quay.io registry
   - Add GitHub webhook triggers for automated builds
   - Configure pull secrets for registry authentication

### PHP Extensions Built from Source

All Containerfiles compile three PECL extensions from source:

1. **igbinary** (v3.2.12): Binary serialization format
2. **msgpack** (v2.1.2): MessagePack serialization library
3. **redis** (v5.3.7): Redis PHP extension with igbinary, msgpack, and lzf support

Extension load order via INI files:
- `40-igbinary.ini` (loads first)
- `40-msgpack.ini` (loads first)
- `50-redis.ini` (loads after dependencies)

### Key Differences Between Containerfiles

- **Containerfile.ubi8**: Includes `dnf -y module reset nginx` and `dnf -y module install nginx:1.20` before installing PHP packages
- **Containerfile.ubi9**: Skips nginx module operations (not needed on UBI9)

Both follow the same pattern: install php-devel and php-pecl-zip, compile extensions, switch back to USER 1001.

## Common Development Commands

### Deploy to OpenShift Cluster

```bash
# Deploy base configuration (uses ImageStreamTags as output)
oc apply -k build/openshift/

# Deploy with custom patches (pushes to quay.io with GitHub triggers)
oc apply -k build/cuppett/
```

### Build Container Images Locally

```bash
# Build UBI8-based PHP 8.0 image
podman build -f Containerfile.ubi8 -t ubi-php:80-ubi8 .

# Build UBI9-based PHP 8.1 image
podman build -f Containerfile.ubi9 -t ubi-php:81-ubi9 .
```

Note: The Containerfile argument passed to BuildConfig determines which base PHP image (7.4, 8.0, or 8.1) is used via the FROM directive.

### Test Built Images

```bash
# Run a test container
podman run -it --rm ubi-php:81-ubi9 php -m

# Verify Redis extension is loaded
podman run -it --rm ubi-php:81-ubi9 php -m | grep redis

# Check extension versions
podman run -it --rm ubi-php:81-ubi9 php -i | grep -E "(igbinary|msgpack|redis)"
```

## Modifying the Project

### Adding a New PHP Extension

1. Add compilation steps to both `Containerfile.ubi8` and `Containerfile.ubi9`
2. Follow the existing pattern: download from PECL, extract, phpize, configure, make, install
3. Create an INI file in `/etc/php.d/` with appropriate load order number (consider dependencies)
4. Clean up build artifacts in the cleanup step

### Updating Extension Versions

Edit the wget URLs in both Containerfiles to point to new PECL versions:
- igbinary: `https://pecl.php.net/get/igbinary-X.Y.Z.tgz`
- msgpack: `https://pecl.php.net/get/msgpack-X.Y.Z.tgz`
- redis: `https://pecl.php.net/get/redis-X.Y.Z.tgz`

### Adding a New PHP/UBI Combination

1. Create new BuildConfig in `build/openshift/buildconfig_ubiX-phpYY.yaml`
2. Reference appropriate base image tag in ImageStream
3. Add BuildConfig to `build/openshift/kustomization.yaml` resources list
4. Create corresponding patch files in `build/cuppett/patches/`
5. Add JSON patch for GitHub trigger in `build/cuppett/kustomization.yaml`

### Customizing for Your Own Registry

Create your own Kustomize overlay similar to `build/cuppett/`:

1. Create directory structure: `build/yourname/{patches,json}`
2. Copy and modify `kustomization.yaml` to reference your patches
3. Update strategic merge patches to point to your registry
4. Optionally configure GitHub webhook triggers

## OpenShift BuildConfig Behavior

- **Triggers**: Builds automatically trigger on base image changes (ImageStream updates) and BuildConfig modifications
- **Run Policy**: Serial (one build at a time per BuildConfig)
- **History Limits**: Retains 5 successful and 5 failed builds
- **Source**: Git repository main branch (https://github.com/cuppett/ubi-php)
- **Strategy**: Docker build using specified Containerfile

## Pre-built Images

Public images are available on quay.io (x86_64 only):
- `quay.io/cuppett/ubi-php:81-ubi9`
- `quay.io/cuppett/ubi-php:80-ubi9`
- `quay.io/cuppett/ubi-php:80-ubi8`
- `quay.io/cuppett/ubi-php:74-ubi8`

## Project Scope

This is a minimal, focused project for building container images. It does not include:
- Application code (these are runtime images)
- Unit tests (validation happens through successful builds)
- Linting tools (Containerfiles follow standard Dockerfile syntax)
- CI/CD pipelines (handled by OpenShift BuildConfigs)

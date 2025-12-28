# OpenShift Build Configuration

This directory contains the base OpenShift resources for building ubi-php container images.

## Deployment

Deploy to your OpenShift cluster:

```bash
oc apply -k build/openshift
```

This will create:
- Namespace: `ubi-php`
- ImageStream: `php` with base Red Hat UBI images
- BuildConfigs: For PHP 8.2 (UBI8), PHP 8.3 (UBI9), PHP 8.3 (UBI10)

Images will be built and stored in the internal OpenShift registry.

## Pushing to External Registry (Optional)

If you want to push images to an external registry like quay.io, you'll need to:

1. **Create a push secret** with your registry credentials:

```bash
# For Quay.io (using robot account credentials recommended)
oc create secret docker-registry quay-push-secret \
  --docker-server=quay.io \
  --docker-username=<your-quay-username> \
  --docker-password=<your-quay-password> \
  --docker-email=<your-email> \
  -n ubi-php

# For Docker Hub
oc create secret docker-registry quay-push-secret \
  --docker-server=docker.io \
  --docker-username=<your-dockerhub-username> \
  --docker-password=<your-dockerhub-password> \
  --docker-email=<your-email> \
  -n ubi-php
```

2. **Create a custom overlay** (see `build/cuppett/` for example):
   - Create patch files to override the output destination
   - Reference `quay-push-secret` in the patch files
   - Update image names to point to your registry

## Creating Your Own Overlay

To customize the builds for your own registry:

1. Copy the `build/cuppett/` directory structure:
   ```bash
   cp -r build/cuppett build/myname
   ```

2. Edit `build/myname/kustomization.yaml` to keep the same structure

3. Edit patch files in `build/myname/patches/` to change:
   - Registry URL (e.g., `quay.io/myname/ubi-php:82-ubi8`)
   - Secret name if different from `quay-push-secret`

4. Deploy your custom overlay:
   ```bash
   oc apply -k build/myname
   ```

## Monitoring Builds

Check build status:

```bash
# List all builds
oc get builds -n ubi-php

# Watch build logs
oc logs -f bc/ubi8-php82 -n ubi-php

# Describe build for troubleshooting
oc describe build ubi8-php82-1 -n ubi-php
```

## Triggering Builds Manually

Builds are automatically triggered when:
- Base image changes (ImageStream update)
- BuildConfig changes
- Git repository changes (if GitHub webhook is configured)

To manually trigger a build:

```bash
oc start-build ubi8-php82 -n ubi-php
```

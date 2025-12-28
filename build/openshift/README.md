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

## Scheduled Builds

A CronJob is included to automatically trigger monthly builds of all images. This ensures images stay up-to-date with security patches from `dnf update` in the Containerfiles.

**Schedule:** 1st of every month at midnight UTC

**What it does:** Triggers builds for all three images:
- `ubi8-php82`
- `ubi9-php83`
- `ubi10-php83`

**Resources created:**
- ServiceAccount: `build-scheduler`
- Role: `build-starter` (permissions to start builds)
- RoleBinding: `build-scheduler-binding`
- CronJob: `monthly-build-trigger`

### Testing the Scheduled Build

To test the CronJob without waiting for the schedule:

```bash
# Create a Job from the CronJob
oc create job --from=cronjob/monthly-build-trigger test-build-trigger -n ubi-php

# Watch the job
oc get jobs -n ubi-php -w

# Check the logs
oc logs job/test-build-trigger -n ubi-php

# Clean up test job
oc delete job test-build-trigger -n ubi-php
```

### Viewing CronJob Status

```bash
# View CronJob details
oc get cronjob monthly-build-trigger -n ubi-php

# View recent Job executions
oc get jobs -n ubi-php -l cronjob=monthly-build-trigger
```

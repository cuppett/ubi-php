# Cuppett Overlay Configuration

This directory contains the Kustomize overlay for deploying ubi-php builds to the cuppett environment, which pushes images to quay.io/cuppett/ubi-php.

## Deployment

Deploy the cuppett configuration:

```bash
oc apply -k build/cuppett/
```

This applies the base configuration from `build/openshift/` with the following customizations:
- Pushes images to `quay.io/cuppett/ubi-php`
- Adds GitHub webhook triggers to BuildConfigs
- Requires the `quay-push-secret` for registry authentication

## GitHub Webhook Setup

The BuildConfigs are configured with GitHub webhook triggers. When you push to the main branch, OpenShift will automatically trigger builds.

### Prerequisites

- OpenShift CLI (`oc`) configured and logged in
- GitHub CLI (`gh`) installed and authenticated
- Push access to the GitHub repository

### Step 1: Get the Webhook URL

Get the webhook URL template from any BuildConfig:

```bash
oc describe bc/ubi8-php82 -n ubi-php | grep -A 3 "Webhook GitHub"
```

You'll see a URL like:
```
https://api.<cluster-domain>/apis/build.openshift.io/v1/namespaces/ubi-php/buildconfigs/ubi8-php82/webhooks/<secret>/github
```

### Step 2: Create the Webhook Secret

Generate a random secret and create it in OpenShift:

```bash
# Generate a secure random secret
WEBHOOK_SECRET=$(openssl rand -hex 20)
echo "Save this for GitHub webhook: $WEBHOOK_SECRET"

# Create the secret in OpenShift
oc create secret generic github-trigger \
  --from-literal=WebHookSecretKey=$WEBHOOK_SECRET \
  -n ubi-php
```

**Important:** Save the `$WEBHOOK_SECRET` value - you'll need it for the next step.

### Step 3: Create the GitHub Webhook

Replace `<secret>` in the webhook URL with your generated secret, then create the webhook using GitHub CLI:

**Using JSON payload (recommended):**

```bash
cat > /tmp/webhook.json <<EOF
{
  "name": "web",
  "active": true,
  "events": ["push"],
  "config": {
    "url": "https://api.<cluster-domain>/apis/build.openshift.io/v1/namespaces/ubi-php/buildconfigs/ubi8-php82/webhooks/$WEBHOOK_SECRET/github",
    "content_type": "json",
    "secret": "$WEBHOOK_SECRET"
  }
}
EOF

gh api repos/cuppett/ubi-php/hooks --method POST --input /tmp/webhook.json
```

**Alternative: Manual Setup via GitHub Web UI**

1. Go to https://github.com/cuppett/ubi-php/settings/hooks
2. Click "Add webhook"
3. Fill in the form:
   - **Payload URL**: The full webhook URL with your secret
   - **Content type**: `application/json`
   - **Secret**: Your `$WEBHOOK_SECRET` value
   - **Events**: Select "Just the push event"
   - **Active**: Checked
4. Click "Add webhook"

### Step 4: Verify the Webhook

Check that the webhook was created:

```bash
# List all webhooks
gh api repos/cuppett/ubi-php/hooks | jq -r '.[] | {id, active, events}'

# Get details of a specific webhook (use the ID from above)
gh api repos/cuppett/ubi-php/hooks/<webhook-id>
```

### Step 5: Test the Webhook

Push a commit to the main branch and verify builds are triggered:

```bash
# Check for new builds
oc get builds -n ubi-php -w

# View build logs
oc logs -f bc/ubi8-php82 -n ubi-php
```

## Webhook Troubleshooting

If builds aren't triggering automatically:

1. **Check webhook deliveries** on GitHub:
   - Go to Settings → Webhooks → Click on your webhook
   - Check "Recent Deliveries" tab for errors

2. **Verify the secret exists** in OpenShift:
   ```bash
   oc get secret github-trigger -n ubi-php
   ```

3. **Check BuildConfig trigger configuration**:
   ```bash
   oc get bc/ubi8-php82 -n ubi-php -o yaml | grep -A 10 triggers
   ```

4. **Test webhook manually** using curl:
   ```bash
   curl -X POST \
     -H "Content-Type: application/json" \
     -H "X-GitHub-Event: push" \
     --data '{"ref":"refs/heads/main"}' \
     "https://api.<cluster-domain>/apis/build.openshift.io/v1/namespaces/ubi-php/buildconfigs/ubi8-php82/webhooks/$WEBHOOK_SECRET/github"
   ```

## Required Secrets

This overlay requires two secrets to be created:

1. **`quay-push-secret`** - Docker registry credentials for pushing to quay.io
   ```bash
   oc create secret docker-registry quay-push-secret \
     --docker-server=quay.io \
     --docker-username=<your-username> \
     --docker-password=<your-password> \
     -n ubi-php
   ```

2. **`github-trigger`** - Webhook secret for GitHub triggers (see above)

## Images Produced

This overlay builds and pushes three images to quay.io:

- `quay.io/cuppett/ubi-php:82-ubi8` - PHP 8.2 on UBI8
- `quay.io/cuppett/ubi-php:83-ubi9` - PHP 8.3 on UBI9
- `quay.io/cuppett/ubi-php:83-ubi10` - PHP 8.3 on UBI10

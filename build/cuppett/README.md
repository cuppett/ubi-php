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

The BuildConfigs are configured with GitHub webhook triggers. When you push to the main branch, OpenShift will automatically trigger builds for **all three images** (ubi8-php82, ubi9-php83, ubi10-php83).

### Prerequisites

- OpenShift CLI (`oc`) configured and logged in
- GitHub CLI (`gh`) installed and authenticated
- Push access to the GitHub repository
- Cluster admin permissions (for RBAC setup)

### Step 1: Configure RBAC for Webhooks

Webhooks need permissions to trigger builds. The base configuration includes RBAC resources that allow unauthenticated webhook access:

- `role-webhook.yaml` - Grants permissions to create buildconfigs/webhooks
- `rolebinding-webhook.yaml` - Binds the role to unauthenticated and authenticated users

These are automatically applied when you deploy with `oc apply -k build/cuppett/`.

**Verify RBAC is configured:**
```bash
oc get role webhook-trigger -n ubi-php
oc get rolebinding webhook-trigger-binding -n ubi-php
```

### Step 2: Get the Webhook URLs

You'll need the webhook URL for each BuildConfig. Get them with:

```bash
oc describe bc/ubi8-php82 -n ubi-php | grep -A 1 "Webhook GitHub"
oc describe bc/ubi9-php83 -n ubi-php | grep -A 1 "Webhook GitHub"
oc describe bc/ubi10-php83 -n ubi-php | grep -A 1 "Webhook GitHub"
```

You'll see URLs like:
```
https://api.<cluster-domain>/apis/build.openshift.io/v1/namespaces/ubi-php/buildconfigs/<buildconfig-name>/webhooks/<secret>/github
```

### Step 3: Create the Webhook Secret

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

### Step 4: Create GitHub Webhooks for All BuildConfigs

**Important:** You need to create **three separate webhooks** - one for each BuildConfig.

Replace `<cluster-domain>` with your actual cluster domain and `$WEBHOOK_SECRET` with your secret, then create all three webhooks:

**Create webhook for ubi8-php82:**
```bash
cat > /tmp/webhook-ubi8.json <<EOF
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

gh api repos/cuppett/ubi-php/hooks --method POST --input /tmp/webhook-ubi8.json
```

**Create webhook for ubi9-php83:**
```bash
cat > /tmp/webhook-ubi9.json <<EOF
{
  "name": "web",
  "active": true,
  "events": ["push"],
  "config": {
    "url": "https://api.<cluster-domain>/apis/build.openshift.io/v1/namespaces/ubi-php/buildconfigs/ubi9-php83/webhooks/$WEBHOOK_SECRET/github",
    "content_type": "json",
    "secret": "$WEBHOOK_SECRET"
  }
}
EOF

gh api repos/cuppett/ubi-php/hooks --method POST --input /tmp/webhook-ubi9.json
```

**Create webhook for ubi10-php83:**
```bash
cat > /tmp/webhook-ubi10.json <<EOF
{
  "name": "web",
  "active": true,
  "events": ["push"],
  "config": {
    "url": "https://api.<cluster-domain>/apis/build.openshift.io/v1/namespaces/ubi-php/buildconfigs/ubi10-php83/webhooks/$WEBHOOK_SECRET/github",
    "content_type": "json",
    "secret": "$WEBHOOK_SECRET"
  }
}
EOF

gh api repos/cuppett/ubi-php/hooks --method POST --input /tmp/webhook-ubi10.json
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

### Step 5: Verify the Webhooks

Check that all three webhooks were created:

```bash
# List all webhooks
gh api repos/cuppett/ubi-php/hooks | jq -r '.[] | {id, active, events, url: .config.url}'
```

You should see three webhooks with URLs pointing to each BuildConfig.

### Step 6: Test the Webhooks

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

2. **Verify RBAC is configured** (403 Forbidden errors):
   ```bash
   oc get role webhook-trigger -n ubi-php
   oc get rolebinding webhook-trigger-binding -n ubi-php
   ```

   If missing, redeploy: `oc apply -k build/cuppett/`

3. **Verify the secret exists** in OpenShift:
   ```bash
   oc get secret github-trigger -n ubi-php
   oc get secret github-trigger -n ubi-php -o jsonpath='{.data.WebHookSecretKey}' | base64 -d
   ```

4. **Check BuildConfig trigger configuration**:
   ```bash
   oc get bc/ubi8-php82 -n ubi-php -o yaml | grep -A 10 triggers
   ```

5. **Test webhook manually** using curl:
   ```bash
   curl -s -X POST \
     -H "Content-Type: application/json" \
     -H "X-GitHub-Event: push" \
     -d '{"ref":"refs/heads/main","repository":{"full_name":"cuppett/ubi-php"}}' \
     "https://api.<cluster-domain>/apis/build.openshift.io/v1/namespaces/ubi-php/buildconfigs/ubi8-php82/webhooks/$WEBHOOK_SECRET/github" | jq -r '.kind, .metadata.name'
   ```

   Should return: `Build` and a build name like `ubi8-php82-9`

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

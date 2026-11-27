# Releasing n-stream

The streaming image: `logstash_meta` and `logstash_status` on psetf read the check results ncgx/nap write to the shared spool and send them to the perfSONAR analytics collector.

## Versions

Releases are numbered `X.Y.Z` and published as `ghcr.io/osg-htc/n-stream:X.Y.Z`.

- **Z:** fixes, and rebuilds with updated packages.
- **Y:** new checks or behaviour.
- **X:** changes that need action when deploying, such as a CheckMK minor upgrade, a site migration or new required configuration.

A release image is never rebuilt or overwritten. A fix is a new release.

Other image tags:

- `:main` is built only by running the Docker workflow by hand, for testing. Do not deploy it.
- PR builds are not pushed anywhere.
- There is no `:latest`.

## What is pinned

- **Base image:** `almalinux/9-base:<version>-<date>` in the `Dockerfile`, never `latest`.
- **Python packages:** exact versions in `requirements.txt`. elasticsearch is pinned because a major version of the client can change the API.
- **Not pinned:** OS packages, taken by `yum update` at build time.

Change a pin in a PR, then release.

## Cutting a release

1. Merge the changes to `main`. **Checks** and the **Docker** build run on every PR.
2. Create the release, which also creates the tag:
   ```
   gh release create X.Y.Z --repo osg-htc/n-stream --target main --generate-notes
   ```
   You can also use the GitHub web page: Releases, then "Draft a new release", with a new tag `X.Y.Z`.
3. The tag starts the Docker workflow, which builds, pushes and signs `ghcr.io/osg-htc/n-stream:X.Y.Z`. Wait for it to finish (`gh run watch`).

## Deploying on psetf

psetf runs the images with podman-compose from `/root/docker-compose.yml`, and nothing updates them automatically. To deploy a release:

1. Set the new `X.Y.Z` in the `image:` line(s), keeping the old line as a comment for rollback.
2. Pull and recreate:
   ```
   podman-compose -f /root/docker-compose.yml pull logstash_meta logstash_status
   podman-compose -f /root/docker-compose.yml up -d logstash_meta logstash_status
   ```
3. To roll back, restore the previous tag and run step 2 again.

Recreating a container discards anything changed inside it by hand. Put such changes in a PR and a release first.

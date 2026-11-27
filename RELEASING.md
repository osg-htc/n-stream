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

psetf runs three containers with podman-compose from `/root/docker-compose.yml`:

- `etf_ps`, the perfsonar-plugins image;
- `logstash_meta` and `logstash_status`, the n-stream image.

Nothing updates them automatically. To deploy a release:

1. **Back up and pin.** Copy `/root/docker-compose.yml` aside. Then set the new `X.Y.Z` in the `image:` line(s), keeping the old line as a comment. Also update `CHECK_MK_VERSION` in the `etf_ps` environment when CheckMK changes; the entrypoint only prints it, but a stale value is misleading.
2. **Tag the running images for rollback.** For example: `podman tag ghcr.io/osg-htc/perfsonar-plugins:<old> localhost/perfsonar-plugins:rollback-<date>`.
3. **Pull:** `podman-compose -f /root/docker-compose.yml pull <services>`.
4. **Recreate.**
   - `etf_ps` alone:
     ```
     podman-compose -f /root/docker-compose.yml up -d --no-deps etf_ps
     ```
   - `logstash_meta` or `logstash_status`: `etf_ps` is declared as depending on them, and podman refuses to remove a container that another container depends on. `up -d` then fails with "has dependent containers" and simply restarts the old containers. So remove `etf_ps` first and bring all three up together:
     ```
     podman stop -t 60 etf_ps logstash_meta logstash_status
     podman rm etf_ps && podman rm logstash_meta logstash_status
     podman-compose -f /root/docker-compose.yml up -d --no-deps logstash_meta logstash_status etf_ps
     ```
   - Leave caddy alone with `--no-deps`.
   - The old containers usually ignore SIGTERM, so each stop waits out its 60 s timeout before podman kills it.
5. **Check:**
   - `podman exec etf_ps omd status etf` says everything is running;
   - `omd version etf` shows the expected CheckMK version;
   - the login at https://psetf.aglt2.org/etf/ redirects to CILogon;
   - the host count is unchanged: `printf 'GET hosts\nStats: state >= 0\n' | lq`, run as the `etf` user;
   - `podman logs logstash_status` shows "messages sent to logstash" on its 5-minute runs.
6. **To roll back,** restore the saved compose file, or point the `image:` lines at the `rollback-<date>` tags, and repeat step 4.

**Expect a pause in checks after a recreate.** A new container starts a fresh CheckMK site with no Nagios retention, that is, no saved check schedule. Nagios therefore spreads the first run of every active check over `max_service_check_spread` (30 minutes):

- no new check results for the first ~5 minutes;
- every check has run once after about 30 minutes;
- n-stream has little to send until then.

Recreating a container discards anything changed inside it by hand. Put such changes in a PR and a release first.

### Overview

**fastlane-flows** is a collection of `fastlane` lanes and custom actions used in `Rambler&Co` projects. Detailed information about workflows types is available in [our Playbook](https://github.com/rambler-ios/team/blob/master/processes/continuous-delivery/workflows.md).

### Lanes

- **In-house** - builds the latest working copy from any branch, builds enterprise version and pushes it to our FTP server.
- **Nightly** - looks pretty similar to in-house lane, but does some additional magic with git tags.
- **Testing** - builds the current `develop` branch state, collects changelog and pushes it to Fabric.
- **Staging** - builds the `release` or `hotfix` branch, does a lot of other interesting stuff and pushes everything to Fabric and TestFlight.

### Custom Actions

- `git_checkout` - Checkouts any branch.
- `git_checkout_release` - Checkouts the latest release or hotfix branch - or creates a new one.
- `git_reset` - Performs a git reset.
- `multiple_tags` - Creates and pushes multple git tags at once.
- `rds_ftp_deploy` - Implements the FTP deploy logic.
- `telegram` - Sends a message to our Telegram chat.

### License

MIT

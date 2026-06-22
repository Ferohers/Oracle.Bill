# Oracle Bill Roadmap

Oracle Bill is a macOS menu bar app that shows month-to-date Oracle Cloud spend in USD per configured account or server group, with clickable rows for warning thresholds.

## Accuracy Principles

- Treat spend as billing data, not instance metadata. Oracle IMDS is useful for identifying a running compute instance from inside OCI, including fields such as `displayName`, `id`, `canonicalRegionName`, `shape`, and tags, but it does not provide authoritative cost totals.
- Use OCI Usage API or Cost Reports as the source of truth. Oracle documents `request-summarized-usages` for cost queries with required `granularity`, `tenantId`, `timeUsageStarted`, and `timeUsageEnded`; it also supports grouping by dimensions such as `resourceId`, `resourceName`, `compartmentId`, `service`, and `region`.
- Surface freshness clearly. Cost Reports are generated every six hours and can be delayed up to 24 hours, so the UI must always show last-updated time and avoid presenting unverified zeroes as real spend.
- Store credentials in Keychain. UserDefaults should hold account metadata only, never API secrets, private keys, or proxy tokens.
- Prefer least-privilege IAM. The account used for cost queries should be limited to reading usage/cost data, such as `read usage-report` or the equivalent Usage API permission model required by the chosen integration.

## Milestone 1: Menu Bar Foundation

- Replace the starter window with a `MenuBarExtra` using `.window` style for a readable compact popover.
- Show total month-to-date spend in the menu bar label using monospaced USD formatting.
- List each configured account separately as `Display Name -- USD Amount`.
- Make each spend row clickable, opening warning controls for that account.
- Add an account manager window for renaming accounts, refreshing usage, and deleting credentials.

## Milestone 2: Credential And Account Model

- Persist account display name, tenancy OCID, home region, warning amount, notification preference, and last verified snapshot.
- Store the user-entered API code or usage proxy URL in Keychain by account ID.
- Support multiple accounts without merging spend unless the user views the total.
- Add validation for tenancy OCID, region format, and accepted credential formats.
- Add an import path for OCI config profiles if native request signing is implemented locally.

## Milestone 3: Billing Integration

- Implement native OCI Signature Version 1 request signing for direct Usage API calls, or standardize an OCI Function/API Gateway proxy response for simpler desktop credentials.
- Query current month-to-date usage with `queryType: COST`, `granularity: DAILY` or `MONTHLY`, `isAggregateByTime: true`, and `groupBy` dimensions suited to the user model.
- For server-level rows, group by `resourceId` and use Compute metadata only to enrich names and tags.
- Normalize returned currency to USD and display non-USD responses as unsupported until conversion rules are explicit.
- Add retry and backoff for throttling and transient failures.

## Milestone 4: Warnings And Notifications

- Request notification permission only when the user enables a warning.
- Trigger local notifications when a verified spend snapshot reaches the configured threshold.
- Prevent duplicate notifications for the same account and billing period unless the amount crosses a new higher threshold.
- Show warning state inline with a bell indicator and the configured USD limit.
- Keep warning controls available from both the menu bar popover and account manager window.

## Milestone 5: Tahoe Design Polish

- Use system materials, semantic colors, compact controls, and native menu bar/window behavior before adding custom glass.
- Keep rows dense and scannable: one name line, one status line, one right-aligned monospaced amount.
- Use standard icon labels with tooltips for compact actions such as add, refresh, and settings.
- Avoid opaque custom backgrounds behind system popovers and settings sheets so Liquid Glass rendering stays legible.
- Validate light mode, dark mode, long account names, high amounts, and narrow popover widths.

## Milestone 6: Reliability And Release

- Add unit tests for formatting, persistence, warning thresholds, and Usage API response parsing.
- Add integration tests with recorded Oracle responses and error payloads.
- Add sandbox entitlements for outbound networking and notifications.
- Add privacy copy explaining what is stored locally and what leaves the Mac.
- Package, sign, notarize, and verify menu bar launch behavior on a clean macOS user account.

## Current Implementation Notes

- The app now has menu bar, account manager, Keychain storage, warning settings, and notification plumbing.
- Direct OCI request signing is implemented for Oracle config blocks with unencrypted RSA PEM keys. Account rows still show connector/error status if OCI rejects the request, permissions are missing, or Usage API returns a non-USD currency.
- A temporary HTTPS proxy response can return JSON with `amountUSD`, `periodStart`, `periodEnd`, and optional `lastUpdated` ISO-8601 fields for early UI testing.

## References

- [Oracle instance metadata documentation](https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/gettingmetadata.htm)
- [Oracle Usage CLI request-summarized-usages documentation](https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/cmdref/usage-api/usage-summary/request-summarized-usages.html)
- [Oracle Cost Reports overview](https://docs.oracle.com/en-us/iaas/Content/Billing/Concepts/costusagereportsoverview.htm)
- [Oracle Cost Analysis overview](https://docs.oracle.com/en-us/iaas/Content/Billing/Concepts/costanalysisoverview.htm)

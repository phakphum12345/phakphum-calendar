# Employee Directory

The directory reads employees from the canonical `Schedule` through
`EmployeeDirectoryService` and merges them with a versioned production
`EmployeeRepository`. Persisted employees override matching schedule identities,
which keeps deactivation and corrected profile details stable without rewriting
historical assignments.

Phase 2 supports search, department and active-state filters, create/edit, and
soft deactivation. The repository uses a dedicated two-slot SharedPreferences
key so a failed staged write cannot replace the last active employee payload.

The directory supports a confirmed merge with the signed-in Google account's
private Drive app-data file for cross-device synchronization. Conflicting
employee codes use the current device's persisted profile. Google Contacts
import/export is user-initiated and previewed before changes; exports only
update contacts previously tagged by this app and never delete contacts.

Expanding a person shows their assignment dates and shift times from the active
canonical schedule. When a roster is loaded from Google Sheets, the app also
reads available Drive revisions transiently and adds changes to the same shift
position to that shift's relationship timeline. If Google does not expose
readable revision exports, the app clearly reports that only the current
assignment could be loaded.

Availability, leave, permissions, employee-specific rates, and profile images
remain later SCE 3.0 phases.

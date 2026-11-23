# Universal Generator → Calendar Adapter

## Safety boundary

The adapter in `lib/features/universal_generator_adapter/` is a new,
isolated integration boundary. It does not replace or modify the existing
Excel import, roster parsing, schedule repositories, calendar sync planner,
Google Calendar gateway, or dependency composition root.

The first increment is deliberately **preview-only**:

- accepts normalized records with explicit batch and source-record IDs;
- requires an explicit title and valid ISO-8601 start/end date-times;
- requires a timezone offset (`+07:00`, for example) or UTC designator (`Z`)
  on both timestamps; timezone-less local timestamps are blocked;
- rejects empty batches, missing IDs, duplicate IDs, invalid timestamps,
  empty titles, and non-positive time ranges;
- encodes batch and source IDs independently when building stable sync IDs,
  preventing delimiter-based identity collisions;
- produces immutable `CalendarEventCandidate` values and blocking findings;
- has no persistence, file-system, network, Google API, or sync dependency;
- always reports that user confirmation is required.

## Interchange contract

A future Universal Generator export should provide a batch ID and records
containing:

- `source_record_id`: stable ID from the source/template mapping process;
- `title`: reviewed event title;
- `start_iso8601` and `end_iso8601`: explicit ISO-8601 date-times with a
  timezone offset or `Z`; timezone-less local values are not accepted;
- optional `description`.

The adapter must not infer dates from sheet names, invent missing times,
deduplicate records by employee/date/title, or silently shift month boundaries.
Ambiguous or incomplete records must remain blocked for review.

## Activation plan

1. Keep this adapter unregistered from the production dependency graph.
2. Verify its pure mapping tests and the repository's existing regression suite.
3. Add a separate preview UI and explicit user approval step in a later PR.
4. Only after approval, integrate through a new opt-in workflow route.
5. Keep the existing Calendar import/sync route available and unchanged.
6. Add end-to-end tests with approved representative files before enabling writes.

No Calendar writes or synchronization are performed by this adapter.

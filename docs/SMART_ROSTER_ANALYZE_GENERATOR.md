# Smart roster Analyze Generator

The smart roster analyzer compares the legacy row parser with the monthly-grid
parser and creates a unified list of shift candidates.

## Pipeline

1. **Read** the source roster using the existing readers.
2. **Analyze** the two result sets using each shift's `sourceKey`.
3. **Generate** candidate shifts that the legacy reader did not return.
4. **Flag** candidates on the same date for the same normalized worker as possible
   duplicates when their source keys differ.
5. **Review** candidates before the normal calendar-sync confirmation flow.

The analyzer is deterministic and local: it does not call an AI service, change
the source spreadsheet, or write to Google Calendar. The word “smart” describes
the multi-reader comparison and duplicate hints, not a claim that uncertain
assignments are automatically verified.

Both Google Sheets reads and local file imports use the same analyzer. This
avoids the prior local-import behavior where a partially successful legacy
parse could suppress all monthly-only candidates.

## Safety and limits

- A matching `sourceKey` is treated as the same assignment.
- A different source key is retained as a candidate, even if it is flagged as a
  possible duplicate. The flag is a review hint, not proof of a duplicate.
- This component does not infer unknown shift times or names; the monthly parser
  must first recognize the row and resolve its date.
- Recovered candidates are not directly synced by the analyzer. Existing app
  confirmation, filtering, and sync controls remain in charge.
- Real-world accuracy must be validated against the original roster, especially
  when checking a reported recovery count such as 23 shifts.

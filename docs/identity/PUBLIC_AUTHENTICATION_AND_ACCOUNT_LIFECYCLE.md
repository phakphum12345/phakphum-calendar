# Public authentication and account lifecycle

Google sign-in establishes identity. Calendar, Drive, Sheets and Contacts access are optional scopes requested incrementally when needed.

Public readiness requires OAuth audience/publication that permits ordinary users, real client IDs and matching redirect URIs per supported platform, and testing with a normal account that is not an owner/developer/tester.

Document first sign-in, account linking, duplicate identity, token refresh/revocation, sign-out, deletion and recovery. Authentication alone does not grant organization access; every organization request checks membership, role and tenant scope. Google Console publication, domain/scope verification and production credentials are external owner actions.
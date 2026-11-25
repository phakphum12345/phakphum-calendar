# Module boundaries and dependency rules

Layers: Presentation (Flutter UI); Application (use cases/orchestration); Domain (entities, policies, calculations, repository contracts); Infrastructure (persistence, HTTP, Google and AI adapters).

Presentation calls application interfaces; application depends on domain contracts; domain must not import Flutter, database/HTTP/Google/provider SDKs; infrastructure implements ports. Cross-feature calls use explicit public contracts.

Each module documents purpose, owned data, public interfaces, dependencies, permissions, persistence, failure states, tests and migration obligations. Inspect dependency graph before refactoring; avoid duplicate services and preserve public contracts with migration tests.
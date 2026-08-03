# ADR 0001: Host-authoritative shared state

Status: accepted

## Context

NETfishing supports private hosts, open hosts, and joined clients. Catches,
currency, owned items, jobs, mail, drawings, profiles, and moderation affect
state that cannot safely trust a client's local presentation.

## Decision

The host validates requests against registered peers and host-owned context,
then performs the authoritative mutation. Clients receive results and replicated
presentation state. Client evidence is bounded and reconstructed where
possible; it is not treated as authority.

Private single-player uses the same host path. Presentation-only state does not
add RPCs or persistence.

## Consequences

- Shared behavior is consistent across private, open-host, and joined-client
  modes.
- Tests must cover local-host and paired host/client paths.
- Stable protocol payloads and rejection cleanup require explicit handling.
- UI activation cannot be used as proof that a server-side mutation succeeded.

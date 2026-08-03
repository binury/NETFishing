# Balance and content notes

Balance is authored data and should change deliberately. This document records
the policy; exact current values remain authoritative in `.tres` resources and
typed scripts.

## Fish

- Stable fish IDs and catalog numbers must not be changed for display cleanup.
- Species availability may constrain water type, time, weather, bait, and other
  authored context.
- Location pools control selection weight; the global catalog remains
  comprehensive.
- Freshwater/saltwater habitat is validated by the host in addition to pool
  membership.
- Value, rarity, quality, and weight ranges should be reviewed together because
  they affect economy and catch difficulty.

## Economy and progression

- Sales and purchases are host-authoritative and must mutate inventory and
  wallet exactly once.
- Reserved assets are rejected atomically; mixed valid/reserved batches must
  not partially succeed.
- Item effects, shop prices, cooler capacity, fishing upgrades, jobs, and
  experience are separate balance axes. Avoid changing several in an unrelated
  presentation pass.

## Recording a balance change

Include in the change description:

1. affected stable IDs and resource paths;
2. old and new values;
3. intended player-facing outcome;
4. interactions with quality, availability, and economy;
5. deterministic validation performed;
6. whether existing saves remain semantically valid.

Do not bump the save schema or network protocol simply because an authored
number changed. Bump a format only when its serialized contract changes.

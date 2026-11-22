# Phone round 2

1. Preparation blocker: prepare() reads meterAssignments/{round_subscriber} before creating it, but its read rule required resource.data membership even when the document did not exist. Firebase therefore rejected the existence check, leaving the already-written round preparing. Resume also rejected already-open rounds and finalized unconditionally, allowing a concurrent cancel/resume race. Fix owner-only missing-document reads, idempotent preparation/finalization, explicit required settings and safe soft cancellation; preserve reader isolation and invoices.

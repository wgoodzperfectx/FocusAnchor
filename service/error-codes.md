# Local replay API error and refusal codes

Contract version: `0.1-replay` (**experimental; not the shared architecture contract**). Service binds to `127.0.0.1` in documented commands and has no Agent, notification, task write or live health adapter. Every model response includes `executable=false`; `gated=false` on M2 means **G0 has not approved it**.

| Code | Transport | Response | Meaning |
|---|---|---|---|
| `INVALID_REQUEST` | HTTP 422 | `code`, `field_paths` | Pydantic request validation, including unknown schema version/source or unsupported extra fields. |
| `BAD_SIGNAL` | HTTP 200 | M1 `physio_state=unknown` | Signal quality is degraded, invalid or unknown. |
| `UNSUPPORTED_WINDOW` | HTTP 200 | M1 `physio_state=unknown` | Replay artifact only accepts 60-second WESAD feature windows. |
| `FEATURE_SET_MISMATCH` | HTTP 200 | M1 unknown / M2 abstain | Required feature names absent or extras supplied. |
| `NONFINITE_FEATURE` | HTTP 200 | M1 unknown / M2 abstain | NaN/Inf numeric feature. |
| `OUT_OF_DISTRIBUTION` | HTTP 200 | M1 unknown / M2 abstain, `ood=true` | At least one feature outside training-user 1st–99th percentile bounds. This is an experimental guard, not a validated OOD detector. |
| `MODEL_UNAVAILABLE` | HTTP 200 | M1 unknown / M2 abstain | Local model file missing or cannot load. |
| `MODEL_ERROR` | HTTP 200 | M1 unknown / M2 abstain | Model inference failed. |
| `REPLAY_UNCALIBRATED` | HTTP 200 | M1 `physio_state=unknown` | All-subject replay model probability has no independent calibration. |
| `BAD_CONTEXT` | HTTP 200 | M2 abstain | Phone context quality not good. |
| `NO_TASK` | HTTP 200 | M2 abstain | No task available. |
| `NEED_UNOBSERVED` | HTTP 200 | M2 abstain | MPUD provides receptivity proxy only; no user help request and no trained need signal. |
| `UNCERTAIN_RECEPTIVITY` | HTTP 200 | M2 abstain | Experimental uncertainty greater than 0.5. |
| `USER_REQUEST_AND_ESM_CLICK_PROXY` | HTTP 200 | M2 ask/defer candidate | Explicit user request plus MPUD click proxy; still not an execution permission. |

HTTP 200 refusals are deliberate machine-readable decisions rather than transport failures. A client must treat timeout, non-200 response, malformed body, incompatible version and `unknown/abstain` as no proactive action. `POST /v1/m2/decision-candidate` cannot directly send a notification or call Agent. `GET /v1/replay/next` returns only synthetic aggregate-median fixtures; no raw participant row or identity.

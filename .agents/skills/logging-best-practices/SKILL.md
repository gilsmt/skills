---
name: logging-best-practices
description: Use before implementing logs in a medium to large scale production system.
---

<!-- Based on ["Logging sucks. And here's how to make it better.](https://loggingsucks.com/) by Boris Tane. -->

When helping with logging, observability, or debugging strategies, follow these principles:

## Core Philosophy

- Logs are optimized for querying, not writing — always design with debugging in mind
- Context is everything — a log without correlation IDs is useless in distributed systems
- Logs are for humans during incidents, not just for compliance or "just in case"
- If you can't filter and search your logs effectively, they provide zero value

## Structured Logging Requirements

- Always use key-value pairs (JSON) instead of string interpolation
- Bad: "Payment failed for user 123"
- Good (with an approved pseudonymous identifier): {"event": "payment_failed", "user_ref": "usr_7k2", "reason": "insufficient_funds", "amount": 99.99}
- Structured logs are machine-parseable, enabling aggregation, alerting, and dashboards

## Required Fields for Every Log Event

- timestamp — ISO 8601 with timezone (e.g., 2025-01-24T20:00:00Z)
- level — debug, info, warn, error (be consistent, don't invent new levels)
- event — machine-readable event name, snake_case (e.g., user_login_success)
- request_id or trace_id — for correlating logs across a single request
- service — which service/application emitted this log
- environment — prod, staging, dev

## Examples of High-Cardinality Fields (include when available and permitted):

- user_id, org_id, account_id — who is affected
- request_id, trace_id, span_id — for distributed tracing
- order_id, transaction_id, job_id — domain-specific identifiers

These fields make logs queryable during incidents. Include person-linked identifiers such as `user_id`, `org_id`, or `account_id` only when they are needed for a defined operational purpose and permitted by the applicable data-classification and privacy policy. Treat them as potentially personal or sensitive data.

When user-level correlation is needed, prefer an approved, purpose-scoped pseudonymous identifier over direct identifiers such as a name, email address, or phone number. Pseudonymous identifiers remain sensitive and still need appropriate access and retention controls. Omit identifiers when they are not needed or are not approved; use request/trace IDs or aggregate data instead. Never log credentials or raw tokens.

Look for opportunities to include approved high-cardinality fields that can help identify the root cause of an issue quickly.

## Context Propagation

- Pass trace/request IDs through all service boundaries (HTTP headers, message queues, etc.)
- Downstream services must inherit correlation IDs from upstream
- Use middleware or interceptors to automatically inject context into every log
- For async jobs, store and restore the original request context

Log Levels — Use Them Correctly:

- debug — Verbose details for local development, usually disabled in production
- info — Normal operations worth recording (user actions, job completions, deploys)
- warn — Something unexpected happened but the system handled it (retries, fallbacks)
- error — Something failed and likely needs human attention (exceptions, failed requests)

Don't log errors for expected conditions (e.g., user enters wrong password)

What to Log:

- Request entry and exit points (with duration)
- State transitions (order created → paid → shipped)
- External service calls (with latency and response codes)
- Authentication and authorization events
- Background job starts, completions, and failures
- Retry attempts and circuit breaker state changes

What NOT to Log:

- Sensitive data (passwords, tokens, credit card numbers, or PII unless its use is necessary and approved; pseudonymous identifiers still require protection)
- Logs inside tight loops (will generate millions of useless entries)
- Success cases that provide no debugging value
- Redundant information already captured by infrastructure (load balancer logs, etc.)

Naming Conventions:

- Be consistent across all services — agree on field names as a team
- Use snake_case for field names: user_id, not userId or user-id
- Use past-tense verbs for events: payment_completed, not complete_payment
- Prefix events by domain when helpful: auth.login_failed, billing.invoice_created

Performance Considerations:

- Use sampling for high-volume debug logs in production
- Avoid logging inside hot paths unless absolutely necessary
- Buffer and batch log writes to reduce I/O overhead
- Consider log levels that can be changed at runtime without redeploying

During Incidents:

- Your logs should answer: Who was affected? What failed? When? Why?
- If you can't answer these within 5 minutes of querying, your logging strategy needs work
- Post-incident: add the logs you wished you had

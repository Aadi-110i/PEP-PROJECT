# API Abuse Rate Limiting - Analytics Report

## Overview
This report extends the SQL backend abuse detection system by providing Python-based analytics and data visualization to identify trends, pinpoint bad actors, and recommend business actions. The data is pulled directly from the API gateway logs.

## Business Insights

### 1. Top Offenders Concentration
**Observation:** A small subset of client IDs consistently account for the vast majority of rate limit violations and subsequent blocks.
**Reason:** Traffic logs for these top offenders show highly uniform sub-second request intervals, indicative of automated scripts/bots ignoring 429 response headers.
**Business Impact:** Concentrated abuse from a few rogue clients degrades overall API reliability, increases latency for legitimate users, and wastes infrastructure resources.
**Recommendation:** Implement strict, progressive penalty windows. If a client is blocked more than 3 times in 24 hours, automatically escalate to a 7-day manual-review blocklist and notify account administrators.

### 2. Peak Abuse Timing
**Observation:** Violation spikes are distinctly clustered around specific off-hours, typically early mornings (2-4 AM UTC).
**Reason:** Many malicious scraping campaigns and brute-force attempts are scheduled via automated cron jobs during expected low-traffic periods to avoid immediate detection.
**Business Impact:** Out-of-hours spikes can overwhelm reduced-capacity server scaling (if auto-scaling down at night) causing severe downtime when no engineers are online.
**Recommendation:** Adjust the token bucket replenishment rates dynamically based on the time of day, making off-hour limits slightly stricter for unauthenticated or low-tier API keys.

### 3. High Error Rate Endpoints
**Observation:** Certain specific endpoints (e.g., `/auth/login` and `/data/export`) exhibit a disproportionately high rate of 4xx and 5xx errors.
**Reason:** `/auth/login` is commonly targeted for credential stuffing, while heavy data endpoints often time out under rapid, unoptimized client queries.
**Business Impact:** These endpoints represent the highest security risk (potential account takeover) and infrastructure risk (database lockups).
**Recommendation:** Decouple rate limits per endpoint. Apply a strict global rate limit specifically on the authentication routes (e.g., max 5 requests/minute per IP) while keeping data routes moderately flexible for legitimate high-volume users.

### 4. Repeat Offender Behavior
**Observation:** A notable percentage of clients are re-blocked very quickly (often within hours) after their initial temporary ban expires.
**Reason:** The offending scripts do not implement exponential backoff; they continue blasting requests into a void, triggering immediate blocks the moment the initial block TTL expires.
**Business Impact:** Temporary bans are largely ineffective against dumb bots, leading to continuous cycle-churning in the blocklist table and noisy audit logs.
**Recommendation:** Implement an escalating ban TTL (Time-To-Live). First offense: 1 hour. Second offense: 24 hours. Third offense: permanent ban requiring manual support intervention.

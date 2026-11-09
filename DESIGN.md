# DESIGN.md — Phoenix Platform

> There is no custom end-user UI. "Design" here = how a reviewer *experiences* the repo, docs, dashboards, and diagrams. Goal: clarity in 2 minutes, depth on demand. Avoid decoration.

## 1. Design Principles

1. **Evidence over adjectives.** Every claim links to a file.
2. **Scannable first, deep second.** Top of README = result; details below.
3. **Consistent templates** for every experiment, drill, ADR, postmortem.
4. **Honest.** Failures are shown, not hidden.

---

## 2. README Layout (order is fixed)

1. Title + one-line tagline
2. **Measured results table** (only values that exist in evidence; otherwise `"not yet measured"`)
3. Architecture diagram (one image, <=12 boxes)
4. 3 Pillars with link to proof each
5. Quick start (copy-paste commands)
6. Evidence index · ADR index · Runbook · Cost
7. Limitations & what I'd do next (builds trust)

**Badges:** CI status, Trivy scan, license. No more than 4.

---

## 3. Documentation Templates

- **ADR:** Status · Context · Decision · Alternatives considered · Consequences (✅/❌) · Evidence link.
- **Chaos report:** Hypothesis · Steady state · Injection method · Observation · Recovery seconds · Result · Dashboard screenshot · Follow-ups.
- **DR scorecard row:** Date · Scenario · RTO · RPO · Data loss · Result · Link.
- **Postmortem:** Summary · Impact · Timeline · Root cause · What went well/badly · Action items (blameless).
- **Runbook entry:** Symptom -> Likely cause -> Verify -> Fix -> Link to alert.

---

## 4. Diagrams

Mermaid or one exported PNG/SVG; single consistent palette: neutral grey boxes, one accent color for "persistent" resources, one for "destroyable". Label data flows with verbs. Include alt text.

---

## 5. Grafana Dashboard Layout

- **Row 1 – SLO status:** availability, latency p95, error-budget remaining (big numbers).
- **Row 2 – Traffic & errors:** RPS, 5xx rate.
- **Row 3 – Platform health:** pod restarts, node CPU/mem, ArgoCD sync status.
- **Row 4 – Reliability:** backup age, last restore result. Rules: consistent units, thresholds colored green/amber/red (+ text, not color-only), annotate chaos injections as vertical markers.

---

## 6. Alert Message Format (Discord)

```text
[SEV] <alert name> — <one-line impact> — runbook: <link> — since <time>
```

---

## 7. Naming & Conventions

Files `kebab-case`; ADRs `NNN-title.md`; evidence `NN-name.md`; dates ISO-8601.

---

## 8. Accessibility

Alt text on screenshots; don't rely on color alone in dashboards; readable heading hierarchy; tables kept <=6 columns.

---

## 9. States

Empty dashboard -> panel description explains scrape target; failed experiments are published with FAIL label and a fix follow-up.


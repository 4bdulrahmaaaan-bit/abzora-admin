# ABZORA Enterprise AR Operations

## 1) AI Fitting System Rollout

### Training Run API
- `POST /ar/ops/fit/runs`
- Payload:
  - `name`
  - `datasetVersion`
  - `trainingConfig`

### Evaluation API
- `POST /ar/ops/fit/runs/:id/evaluate`
- Payload:
  - `metrics` (MAE, weighted fit accuracy, coverage, calibration error)
  - `notes`

### Rollout API
- `POST /ar/ops/fit/runs/:id/rollout`
- Payload:
  - `percentage` (1-100)
  - `channel` (`shadow`, `canary`, `full`)

### Governance Checklist
- Holdout bias report attached
- SKU/category parity validated
- Segment drift vs previous model checked
- Canary rollback threshold configured

### Real Training Executor
- Worker reads dataset from `backend/storage/ar-datasets/<datasetVersion>.json`
- Trains lightweight regression model on normalized body+garment features
- Writes artifacts to `backend/storage/ar-models/<modelVersion>/`
  - `weights.json`
  - `feature_map.json`
  - `metrics.json`
  - `calibration_map.json`
  - `eval_report.json`

## 2) Garment Certification / LOD Automation

### Job API
- `POST /ar/ops/garment/jobs`
- `GET /ar/ops/garment/jobs`

### Certification Gates
- HTTPS model URL present
- Preview image present
- LOD eligibility computed
- Certification status emitted per product
- Budget policy checks:
  - model byte budget by tier
  - texture byte budget by tier
  - triangle estimate budget by tier
  - scored quality decision with rejection reasons

### Scale Recommendations
- Split full-catalog jobs by category
- Keep job findings capped and stream detailed logs to object storage
- Attach mesh/texture validator output in findings

## 3) Device-Lab Soak / Perf Validation

### Run API
- `POST /ar/ops/device-lab/runs`
- `GET /ar/ops/device-lab/runs`

### Matrix Coverage
- LOW (2-3 Android models)
- MID (3-4 Android models)
- FLAGSHIP (3+ Android/iOS models)
- PREMIUM_LIDAR (2+ iPhone Pro/iPad Pro class devices)

### Soak Scenarios
- 30m baseline
- 45m capture-heavy session
- 60m catalog-switch stress
- Thermal degraded mode pass

## 4) Cross-Surface Analytics

### Summary API
- `GET /ar/ops/enterprise/summary?days=14`

### Dashboard Scope
- Session quality, FPS, tracking risk
- Fit run count and rollout count
- Garment certification throughput
- Device-lab pass/fail trends

## 5) One-Command Nightly Orchestration

Run:

```bash
node scripts/ar_enterprise_rollout.mjs
```

## 6) Worker Runtime

Enabled by default:
- `AR_MODEL_WORKER_ENABLED=true`
- `AR_GARMENT_CERT_WORKER_ENABLED=true`

Health endpoint:
- `GET /ar/ops/workers/health`

## 7) Model Artifact Registry

Endpoint:
- `GET /ar/ops/fit/artifacts?modelVersion=...`

Stored artifacts include:
- metrics
- eval_report
- feature_map (future)
- calibration_map (future)
- weights (future)

## 8) Scripted Model Promotion

```bash
node scripts/ar_fit_promote.mjs <runId> canary 10
```

Gate policy currently enforced at rollout:
- `weightedAccuracy >= 0.82`
- `calibrationError <= 0.12`
- `mae <= 0.18`

## 9) Dataset Generation Utility

```bash
npm run ar:data:generate-fit -- dataset-v2 8000
```

Required env:
- `BACKEND_BASE_URL`
- `ADMIN_BEARER_TOKEN`
- `AR_DATASET_VERSION` (optional)
- `AR_GARMENT_JOB_MODE` (optional)
- `AR_SOAK_SCENARIO` (optional)

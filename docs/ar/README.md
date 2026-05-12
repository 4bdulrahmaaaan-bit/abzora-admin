# ABZORA AR Payload Contract (Flutter <-> Backend <-> Unity)

This folder defines the runtime contract for AR try-on.

## Files

- `unity_try_on_payload.schema.json`
  - Canonical schema for the product payload Unity receives.
- `fit_score_request.schema.json`
  - Request schema for `POST /ar/fit/score`.
- `samples/try_on_product_response.sample.json`
  - Realistic sample for `GET /ar/product/:id`.
- `samples/fit_score_response.sample.json`
  - Realistic sample for `POST /ar/fit/score`.

## Integration Notes

- Unity should always prefer `garmentConfig.lodModels` and fall back to `model3d`.
- `template.customizableParts` is the source of valid design slots/options.
- `garmentConfig.designOptions` must only use keys defined in `customizableParts`.
- `fitScore` is 0-100 and should be shown with `recommendedSize`.

# ABZORA 3D Asset Pipeline

Folder structure:

- `assets/3d/shirts/`
- `assets/3d/pants/`
- `assets/3d/jackets/`

Rules:

- Export only `GLB` or `GLTF`.
- Keep textures mobile-ready (`512px` to `1K`).
- Keep scale and rig consistent for all garments.
- Register each new model inside `assets/3d/asset_manifest.json`.
- Set `product.model3d` in backend to either:
  - a manifest `id` (example: `shirt_001`), or
  - a direct `.glb` URL.

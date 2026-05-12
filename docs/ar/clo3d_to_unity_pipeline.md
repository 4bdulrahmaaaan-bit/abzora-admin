# ABZORA CLO3D -> Unity Garment Pipeline

## 1. Authoring in CLO3D
- Build garment pattern using real measurement blocks.
- Assign fabric simulation params:
  - weight
  - stretch (warp/weft)
  - bending
  - friction
- Freeze final drape at fit presets: `slim`, `regular`, `relaxed`.

## 2. Export
- Primary: `FBX` (skinned)
- Fallback: `OBJ` (static)
- Export texture sets:
  - Albedo
  - Normal
  - Roughness

## 3. Optimization
- Retopology target:
  - LOD0: 25k-40k tris
  - LOD1: 10k-18k tris
  - LOD2: 4k-8k tris
- Bake normals from high-poly into LOD meshes.
- Remove hidden/internal faces.

## 4. Rigging
- Use humanoid-compatible skeleton (Unity import Humanoid/Generic as needed).
- Validate weights on shoulders, chest, waist, hips.
- Name blend shapes consistently with runtime keys:
  - `chest_expand`
  - `waist_expand`
  - `hip_expand`
  - per-style shapes (example: `sleeve_length`)

## 5. Unity Import
- Import FBX as `SkinnedMeshRenderer`.
- Configure materials for URP/HDRP target.
- Add lightweight cloth behavior (optional GPU motion or constrained cloth).

## 6. AssetBundle Build
- Build per template/version:
  - `template-slug/v{n}/lod0.bundle`
  - `template-slug/v{n}/lod1.bundle`
  - `template-slug/v{n}/lod2.bundle`
- Keep deterministic naming for CDN cache invalidation.

## 7. CDN Publishing
- Upload model bundles + texture maps to CDN.
- Set immutable cache headers for versioned paths.
- Update template record using `/ar/templates/upsert`.

## 8. Runtime Validation
- Run Unity QA checklist:
  - load each LOD manually
  - verify blend shapes respond
  - verify customization slots (`collar_*`, `sleeve_*`)
  - verify fit score callbacks to Flutter

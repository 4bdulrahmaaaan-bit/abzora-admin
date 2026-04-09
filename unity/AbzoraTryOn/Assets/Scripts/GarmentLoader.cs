using UnityEngine;
using UnityEngine.AssetBundleModule;

namespace Abzora.TryOn
{
    public class GarmentLoader : MonoBehaviour
    {
        [SerializeField] private Transform garmentRoot;
        [SerializeField] private Material defaultMaterial;

        private GameObject _activeGarment;
        private AssetBundle _activeBundle;

        public void LoadFromBundle(AssetBundle bundle, UnityTryOnPayload payload)
        {
            ClearGarment();
            _activeBundle = bundle;

            var prefabNames = bundle.GetAllAssetNames();
            if (prefabNames.Length == 0)
            {
                LoadPlaceholderMesh(payload);
                return;
            }

            var prefab = bundle.LoadAsset<GameObject>(prefabNames[0]);
            if (prefab == null)
            {
                LoadPlaceholderMesh(payload);
                return;
            }

            _activeGarment = Instantiate(prefab, garmentRoot);
            ApplyMaterialProfile(payload.materialProfile);
        }

        public void LoadPlaceholderMesh(UnityTryOnPayload payload)
        {
            ClearGarment();
            var garment = GameObject.CreatePrimitive(PrimitiveType.Quad);
            garment.name = $"{payload.category}_placeholder";
            garment.transform.SetParent(garmentRoot, false);
            garment.transform.localScale = new Vector3(0.7f, 1.0f, 1f);
            if (defaultMaterial != null)
            {
                var renderer = garment.GetComponent<MeshRenderer>();
                renderer.sharedMaterial = defaultMaterial;
            }
            _activeGarment = garment;
        }

        public void ClearGarment()
        {
            if (_activeGarment != null)
            {
                Destroy(_activeGarment);
                _activeGarment = null;
            }

            if (_activeBundle != null)
            {
                _activeBundle.Unload(unloadAllLoadedObjects: false);
                _activeBundle = null;
            }
        }

        private void ApplyMaterialProfile(string materialProfile)
        {
            if (_activeGarment == null || string.IsNullOrWhiteSpace(materialProfile))
            {
                return;
            }

            var renderers = _activeGarment.GetComponentsInChildren<Renderer>(true);
            foreach (var renderer in renderers)
            {
                renderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                renderer.receiveShadows = false;
            }
        }
    }
}

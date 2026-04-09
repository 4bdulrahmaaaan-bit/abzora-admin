using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Networking;

namespace Abzora.TryOn
{
    public class FlutterUnityBridge : MonoBehaviour
    {
        public static FlutterUnityBridge Instance { get; private set; }

        [SerializeField] private PoseReceiver poseReceiver;
        [SerializeField] private GarmentLoader garmentLoader;
        [SerializeField] private AvatarRigController avatarRigController;
        [SerializeField] private TryOnCaptureController captureController;

        private string _activeProductId = string.Empty;

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }

            Instance = this;
            DontDestroyOnLoad(gameObject);
            EmitEvent("unity_ready", new Dictionary<string, object>
            {
                { "renderer", "unity_premium" },
                { "timestampMs", DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() },
            });
        }

        public void InitializeTryOn(string json)
        {
            var payload = JsonUtility.FromJson<UnityTryOnPayload>(json);
            if (payload == null)
            {
                EmitError("initialize_failed", "Invalid initialization payload.");
                return;
            }

            _activeProductId = payload.productId ?? string.Empty;
            avatarRigController?.ApplyMeasurements(payload.measurements);
            if (!string.IsNullOrWhiteSpace(payload.unityAssetBundleUrl))
            {
                StartCoroutine(LoadGarmentBundle(payload));
                return;
            }

            if (!string.IsNullOrWhiteSpace(payload.model3dUrl))
            {
                StartCoroutine(LoadModel(payload.model3dUrl, payload));
                return;
            }

            EmitEvent("unity_initialized", new Dictionary<string, object>
            {
                { "productId", _activeProductId },
                { "renderer", "unity_premium" },
            });
        }

        public void LoadGarment(string json)
        {
            InitializeTryOn(json);
        }

        public void UpdatePose(string json)
        {
            var payload = JsonUtility.FromJson<UnityPosePayload>(json);
            if (payload == null || payload.poseFrame == null)
            {
                return;
            }

            poseReceiver?.ApplyPose(payload.poseFrame);
        }

        public void SetMeasurements(string json)
        {
            var payload = JsonUtility.FromJson<UnityMeasurementPayload>(json);
            if (payload == null)
            {
                return;
            }

            avatarRigController?.ApplyMeasurements(payload.measurements);
        }

        public string Capture()
        {
            if (captureController == null)
            {
                EmitError("capture_unavailable", "Capture controller is missing.");
                return string.Empty;
            }

            var path = captureController.CaptureToFile(_activeProductId);
            EmitEvent("capture_complete", new Dictionary<string, object>
            {
                { "productId", _activeProductId },
                { "path", path },
            });
            return path;
        }

        public void DisposeSession()
        {
            garmentLoader?.ClearGarment();
            poseReceiver?.ResetPose();
            EmitEvent("unity_disposed", new Dictionary<string, object>
            {
                { "productId", _activeProductId },
            });
        }

        private IEnumerator LoadGarmentBundle(UnityTryOnPayload payload)
        {
            EmitEvent("garment_loading", new Dictionary<string, object>
            {
                { "productId", payload.productId },
                { "source", "asset_bundle" },
            });

            using var request = UnityWebRequestAssetBundle.GetAssetBundle(payload.unityAssetBundleUrl);
            yield return request.SendWebRequest();
            if (request.result != UnityWebRequest.Result.Success)
            {
                EmitError("bundle_load_failed", request.error);
                yield break;
            }

            var bundle = DownloadHandlerAssetBundle.GetContent(request);
            if (bundle == null)
            {
                EmitError("bundle_invalid", "Asset bundle content was null.");
                yield break;
            }

            garmentLoader?.LoadFromBundle(bundle, payload);
            EmitEvent("garment_loaded", new Dictionary<string, object>
            {
                { "productId", payload.productId },
                { "source", "asset_bundle" },
            });
        }

        private IEnumerator LoadModel(string modelUrl, UnityTryOnPayload payload)
        {
            EmitEvent("garment_loading", new Dictionary<string, object>
            {
                { "productId", payload.productId },
                { "source", "model_url" },
            });

            using var request = UnityWebRequest.Get(modelUrl);
            yield return request.SendWebRequest();
            if (request.result != UnityWebRequest.Result.Success)
            {
                EmitError("model_load_failed", request.error);
                yield break;
            }

            garmentLoader?.LoadPlaceholderMesh(payload);
            EmitEvent("garment_loaded", new Dictionary<string, object>
            {
                { "productId", payload.productId },
                { "source", "model_url" },
            });
        }

        private void EmitError(string code, string message)
        {
            EmitEvent("unity_error", new Dictionary<string, object>
            {
                { "code", code },
                { "message", message },
            });
        }

        private void EmitEvent(string eventName, Dictionary<string, object> data)
        {
            Debug.Log($"[ABZORA Unity] {eventName}: {MiniJson.Serialize(data)}");
        }
    }

    [Serializable]
    public class UnityTryOnPayload
    {
        public string productId;
        public string name;
        public string category;
        public string model3dUrl;
        public string unityAssetBundleUrl;
        public string rigProfile;
        public string materialProfile;
        public UnityMeasurementMap measurements;
    }

    [Serializable]
    public class UnityMeasurementPayload
    {
        public UnityMeasurementMap measurements;
    }

    [Serializable]
    public class UnityMeasurementMap
    {
        public float heightCm;
        public float shoulderCm;
        public float chestCm;
        public float waistCm;
        public float hipCm;
    }

    [Serializable]
    public class UnityPosePayload
    {
        public UnityPoseFrame poseFrame;
    }

    [Serializable]
    public class UnityPoseFrame
    {
        public UnityPosePoint leftShoulder;
        public UnityPosePoint rightShoulder;
        public UnityPosePoint leftHip;
        public UnityPosePoint rightHip;
        public UnityPosePoint shoulderCenter;
        public UnityPosePoint hipCenter;
        public float rotationRadians;
        public float shoulderWidth;
        public float torsoHeight;
    }

    [Serializable]
    public class UnityPosePoint
    {
        public float x;
        public float y;
    }
}

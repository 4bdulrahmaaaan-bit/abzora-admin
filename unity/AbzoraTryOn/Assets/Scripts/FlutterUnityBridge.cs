using System;
using System.Collections.Generic;
using UnityEngine;

namespace Abzora.TryOn
{
    public class FlutterUnityBridge : MonoBehaviour
    {
        public static FlutterUnityBridge Instance { get; private set; }

        [SerializeField] private TryOnCaptureController captureController;
        [SerializeField] private TryOnManager tryOnManager;

        private readonly Queue<string> _eventQueue = new Queue<string>();
        private string _activeProductId = string.Empty;
        private TryOnPayload _activePayload;

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }

            Instance = this;
            DontDestroyOnLoad(gameObject);
            if (tryOnManager != null)
            {
                tryOnManager.OnLoaded += HandleManagerEvent;
                tryOnManager.OnFitCalculated += HandleManagerEvent;
                tryOnManager.OnError += HandleManagerEvent;
                tryOnManager.OnBodyDetection += HandleManagerEvent;
            }
            EmitEvent("unity_ready", new Dictionary<string, object>
            {
                { "renderer", "unity_premium" },
                { "timestampMs", DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() },
            });
        }

        public void InitializeTryOn(string json)
        {
            if (tryOnManager == null)
            {
                EmitError("manager_missing", "TryOnManager is not assigned.");
                return;
            }
            var payload = TryOnPayloadParser.Parse(json);
            _activePayload = payload;
            _activeProductId = payload?.ProductId ?? string.Empty;
            tryOnManager.InitializeFromJson(json);
        }

        public void LoadGarment(string json)
        {
            InitializeTryOn(json);
        }

        public void UpdatePose(string json)
        {
            var payload = TryOnPayloadParser.ParsePose(json);
            if (payload?.PoseFrame == null)
            {
                return;
            }
            tryOnManager?.UpdatePoseFromJson(json);
        }

        public void SetMeasurements(string json)
        {
            var payload = TryOnPayloadParser.Parse(json);
            if (payload == null)
            {
                return;
            }

            if (_activePayload == null)
            {
                _activePayload = payload;
            }
            else
            {
                _activePayload.Measurements = payload.Measurements ?? _activePayload.Measurements;
            }

            tryOnManager?.UpdateMeasurementsFromJson(json);
        }

        public void UpdateGarmentConfig(string json)
        {
            tryOnManager?.UpdateGarmentConfigFromJson(json);
        }

        public void SetViewTransform(string json)
        {
            tryOnManager?.SetViewTransformFromJson(json);
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

        public bool StartVideoRecording()
        {
            if (captureController == null)
            {
                EmitError("recording_unavailable", "Capture controller is missing.");
                return false;
            }

            var started = captureController.StartVideoRecording(_activeProductId);
            EmitEvent("recording_started", new Dictionary<string, object>
            {
                { "productId", _activeProductId },
                { "started", started },
            });
            return started;
        }

        public string StopVideoRecording()
        {
            if (captureController == null)
            {
                EmitError("recording_unavailable", "Capture controller is missing.");
                return string.Empty;
            }

            var manifestPath = captureController.StopVideoRecording();
            EmitEvent("recording_stopped", new Dictionary<string, object>
            {
                { "productId", _activeProductId },
                { "path", manifestPath },
                { "format", "frame_sequence" },
            });
            return manifestPath;
        }

        public void DisposeSession()
        {
            tryOnManager?.DisposeSession();
            _activePayload = null;
            EmitEvent("unity_disposed", new Dictionary<string, object>
            {
                { "productId", _activeProductId },
            });
        }

        // Exposed for native bridge pull mode if needed.
        public string DequeueEventJson()
        {
            return _eventQueue.Count > 0 ? _eventQueue.Dequeue() : string.Empty;
        }

        private void HandleManagerEvent(Dictionary<string, object> payload)
        {
            if (payload == null)
            {
                return;
            }
            var type = payload.TryGetValue("type", out var typeValue)
                ? (typeValue?.ToString() ?? string.Empty)
                : string.Empty;
            EmitEvent(type, payload);
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
            if (data == null)
            {
                data = new Dictionary<string, object>();
            }
            if (!data.ContainsKey("type"))
            {
                data["type"] = eventName;
            }
            data["productId"] = data.ContainsKey("productId")
                ? data["productId"]
                : _activeProductId;
            data["timestampMs"] = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

            var json = MiniJson.Serialize(data);
            _eventQueue.Enqueue(json);
            Debug.Log($"[ABZORA Unity] {eventName}: {json}");
            FlutterUnityTransport.SendMessageToFlutter(json);
        }
    }
}

using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using UnityEngine;

namespace Abzora.TryOn
{
    public class TryOnManager : MonoBehaviour
    {
        [SerializeField] private TryOnBinder binder;

        public event Action<Dictionary<string, object>> OnLoaded;
        public event Action<Dictionary<string, object>> OnFitCalculated;
        public event Action<Dictionary<string, object>> OnError;
        public event Action<Dictionary<string, object>> OnBodyDetection;

        private TryOnPayload _activePayload;
        private bool _isBusy;
        private bool _bodyDetected;

        public TryOnPayload ActivePayload => _activePayload;

        public void InitializeFromJson(string json)
        {
            var payload = TryOnPayloadParser.Parse(json);
            if (payload == null)
            {
                EmitError("payload_parse_failed", "Failed to parse try-on payload.");
                return;
            }

            _activePayload = payload;
            StartCoroutine(InitializeRoutine(payload));
        }

        public void UpdateMeasurementsFromJson(string json)
        {
            var payload = TryOnPayloadParser.Parse(json);
            if (payload == null || payload.Measurements == null)
            {
                return;
            }

            if (_activePayload == null)
            {
                _activePayload = payload;
            }
            else
            {
                _activePayload.Measurements = payload.Measurements;
            }
            binder.ApplyMeasurements(_activePayload);
            EmitFitResult();
        }

        public void UpdatePoseFromJson(string json)
        {
            var posePayload = TryOnPayloadParser.ParsePose(json);
            if (posePayload == null || posePayload.PoseFrame == null)
            {
                EmitBodyDetection(false, 0f);
                return;
            }
            var confidence = Mathf.Clamp01(
                ((posePayload.PoseFrame.ShoulderWidth * 2.2f) +
                 (posePayload.PoseFrame.TorsoHeight * 2.1f)) * 0.5f
            );
            EmitBodyDetection(confidence >= 0.25f, confidence);
            binder.ApplyPoseFrame(posePayload.PoseFrame);
            binder.UpdateLighting(posePayload.PoseFrame.LightingScore);
        }

        public void UpdateGarmentConfigFromJson(string json)
        {
            var payload = TryOnPayloadParser.Parse(json);
            if (payload == null)
            {
                return;
            }
            _activePayload = payload;
            StartCoroutine(binder.ApplyRuntimeConfig(_activePayload));
            EmitFitResult();
        }

        public void SetViewTransformFromJson(string json)
        {
            var payload = MiniJson.Deserialize(json) as Dictionary<string, object>;
            if (payload == null)
            {
                return;
            }
            var rotateY = 0f;
            var zoom = 1f;
            if (payload.TryGetValue("rotateY", out var rotate))
            {
                float.TryParse(rotate?.ToString(), NumberStyles.Float, CultureInfo.InvariantCulture, out rotateY);
            }
            if (payload.TryGetValue("zoom", out var zoomValue))
            {
                float.TryParse(zoomValue?.ToString(), NumberStyles.Float, CultureInfo.InvariantCulture, out zoom);
            }
            binder.SetViewTransform(rotateY, zoom);
        }

        public void DisposeSession()
        {
            _activePayload = null;
            binder.DisposeSession();
        }

        private IEnumerator InitializeRoutine(TryOnPayload payload)
        {
            if (_isBusy)
            {
                yield break;
            }
            _isBusy = true;

            var loadFailed = false;
            var errorCode = string.Empty;
            var errorMessage = string.Empty;
            yield return StartCoroutine(
                binder.Bind(payload, onError: (code, message) =>
                {
                    loadFailed = true;
                    errorCode = code ?? "bind_failed";
                    errorMessage = message ?? "Unable to initialize AR try-on.";
                }));

            _isBusy = false;

            if (loadFailed)
            {
                EmitError(errorCode, errorMessage);
                yield break;
            }

            OnLoaded?.Invoke(new Dictionary<string, object>
            {
                { "type", "onLoaded" },
                { "productId", payload.ProductId },
                { "templateId", payload.TemplateId },
                { "category", payload.Category },
            });

            EmitFitResult();
        }

        private void EmitFitResult()
        {
            var fit = binder.ComputeFitData(_activePayload);
            OnFitCalculated?.Invoke(new Dictionary<string, object>
            {
                { "type", "onFitCalculated" },
                { "productId", _activePayload?.ProductId ?? string.Empty },
                { "templateId", _activePayload?.TemplateId ?? string.Empty },
                { "recommendedSize", fit.RecommendedSize },
                { "fitScore", fit.FitScore },
                { "confidence", fit.Confidence },
                { "fitLabel", fit.FitLabel },
                { "bodyType", fit.BodyType },
                { "riskLevel", fit.RiskLevel },
                { "fitWarnings", fit.FitWarnings?.ToArray() ?? Array.Empty<string>() },
            });
        }

        private void EmitError(string code, string message)
        {
            OnError?.Invoke(new Dictionary<string, object>
            {
                { "type", "onError" },
                { "code", code ?? "tryon_error" },
                { "message", message ?? "Unexpected AR error." },
                { "productId", _activePayload?.ProductId ?? string.Empty },
            });
        }

        private void EmitBodyDetection(bool detected, float confidence)
        {
            if (_bodyDetected == detected)
            {
                return;
            }
            _bodyDetected = detected;
            OnBodyDetection?.Invoke(new Dictionary<string, object>
            {
                { "type", "onBodyDetection" },
                { "detected", detected },
                { "confidence", confidence },
                { "productId", _activePayload?.ProductId ?? string.Empty },
            });
        }
    }
}

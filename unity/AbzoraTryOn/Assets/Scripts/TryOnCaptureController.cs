using System;
using System.IO;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Abzora.TryOn
{
    public class TryOnCaptureController : MonoBehaviour
    {
        [SerializeField] private int recordingFps = 15;
        [SerializeField] private string brandingText = "ABZORA TRY-ON";

        private bool _isRecording;
        private Coroutine _recordingRoutine;
        private readonly List<string> _recordedFrames = new List<string>();
        private string _recordingSessionId = string.Empty;

        public string CaptureToFile(string productId)
        {
            var safeProductId = string.IsNullOrWhiteSpace(productId) ? "tryon" : productId;
            var fileName = $"{safeProductId}_{DateTime.UtcNow:yyyyMMdd_HHmmss}.png";
            var path = Path.Combine(Application.temporaryCachePath, fileName);
            ScreenCapture.CaptureScreenshot(path, 1);
            return path;
        }

        public bool StartVideoRecording(string productId)
        {
            if (_isRecording)
            {
                return true;
            }

            _recordedFrames.Clear();
            _recordingSessionId = $"{(string.IsNullOrWhiteSpace(productId) ? "tryon" : productId)}_{DateTime.UtcNow:yyyyMMdd_HHmmss}";
            _isRecording = true;
            _recordingRoutine = StartCoroutine(CaptureFramesLoop());
            return true;
        }

        public string StopVideoRecording()
        {
            if (!_isRecording)
            {
                return string.Empty;
            }

            _isRecording = false;
            if (_recordingRoutine != null)
            {
                StopCoroutine(_recordingRoutine);
                _recordingRoutine = null;
            }

            var manifestPath = Path.Combine(Application.temporaryCachePath, $"{_recordingSessionId}_frames.txt");
            File.WriteAllLines(manifestPath, _recordedFrames);
            return manifestPath;
        }

        public bool IsRecording()
        {
            return _isRecording;
        }

        private IEnumerator CaptureFramesLoop()
        {
            var wait = new WaitForSeconds(Mathf.Max(0.03f, 1f / Mathf.Max(1, recordingFps)));
            while (_isRecording)
            {
                var framePath = Path.Combine(
                    Application.temporaryCachePath,
                    $"{_recordingSessionId}_frame_{_recordedFrames.Count:D5}.png"
                );
                ScreenCapture.CaptureScreenshot(framePath, 1);
                _recordedFrames.Add(framePath);
                yield return wait;
            }
        }
    }
}

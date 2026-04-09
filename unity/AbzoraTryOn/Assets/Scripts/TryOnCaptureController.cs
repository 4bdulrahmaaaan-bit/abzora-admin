using System;
using System.IO;
using UnityEngine;

namespace Abzora.TryOn
{
    public class TryOnCaptureController : MonoBehaviour
    {
        public string CaptureToFile(string productId)
        {
            var safeProductId = string.IsNullOrWhiteSpace(productId) ? "tryon" : productId;
            var fileName = $"{safeProductId}_{DateTime.UtcNow:yyyyMMdd_HHmmss}.png";
            var path = Path.Combine(Application.temporaryCachePath, fileName);
            ScreenCapture.CaptureScreenshot(path, 1);
            return path;
        }
    }
}

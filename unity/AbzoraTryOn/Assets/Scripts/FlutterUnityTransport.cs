using System;
using UnityEngine;

namespace Abzora.TryOn
{
    internal static class FlutterUnityTransport
    {
        public static void SendMessageToFlutter(string message)
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            try
            {
                using (var bridge = new AndroidJavaClass("com.xraph.plugin.flutter_unity_widget.UnityPlayerUtils"))
                {
                    bridge.CallStatic("onUnityMessage", message);
                }
            }
            catch (Exception exception)
            {
                Debug.LogWarning($"[ABZORA Unity] Failed to send message to Flutter: {exception.Message}");
            }
#elif UNITY_IOS && !UNITY_EDITOR
            Debug.Log($"[ABZORA Unity] iOS bridge not configured. Message: {message}");
#else
            Debug.Log($"[ABZORA Unity] Editor bridge message: {message}");
#endif
        }
    }
}

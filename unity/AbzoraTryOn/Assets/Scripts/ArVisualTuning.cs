using UnityEngine;

namespace Abzora.TryOn
{
    [CreateAssetMenu(
        fileName = "ArVisualTuning",
        menuName = "ABZORA/AR Visual Tuning",
        order = 10)]
    public class ArVisualTuning : ScriptableObject
    {
        [Header("Tracking Smoothing")]
        public float PositionLerp = 0.28f;
        public float RotationLerp = 0.22f;
        public float MaxPositionStep = 0.085f;
        public float MaxRotationStepDegrees = 10f;
        public float MaxScaleStep = 0.09f;

        [Header("Garment Entry")]
        public float EntryDropDistance = 0.24f;
        public float EntryDuration = 0.38f;

        [Header("Micro Motion")]
        public float MotionScaleLerp = 7f;
        public float SwayAmplitude = 0.008f;
        public float SwaySpeed = 0.9f;
        public float BreathingAmplitude = 0.012f;
        public float BreathingSpeed = 0.55f;

        [Header("LOD + Performance")]
        public float NearLodDistance = 1.4f;
        public float MidLodDistance = 2.3f;
        public float LowFpsThreshold = 28f;
        public float FpsCheckWindowSeconds = 0.75f;

        [Header("Lighting")]
        public Color AmbientLight = new Color(0.62f, 0.64f, 0.68f, 1f);
        public float AmbientIntensity = 1.08f;
    }
}

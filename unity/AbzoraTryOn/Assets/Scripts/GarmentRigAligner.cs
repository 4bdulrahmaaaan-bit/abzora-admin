using UnityEngine;

namespace Abzora.TryOn
{
    public class GarmentRigAligner : MonoBehaviour
    {
        [SerializeField] private PoseReceiver poseReceiver;
        [SerializeField] private float chestRotationLerp = 0.26f;
        [SerializeField] private float armRotationLerp = 0.3f;
        [SerializeField] private float maxArmRotationStep = 14f;

        private Transform _chestBone;
        private Transform _spineBone;
        private Transform _neckBone;
        private Transform _leftUpperArmBone;
        private Transform _rightUpperArmBone;
        private Transform _leftLowerArmBone;
        private Transform _rightLowerArmBone;

        public void Bind(GameObject garmentRoot)
        {
            if (garmentRoot == null)
            {
                return;
            }
            if (poseReceiver == null)
            {
                poseReceiver = GetComponent<PoseReceiver>();
            }

            _chestBone = FindBone(garmentRoot.transform, "chest", "upperchest", "spine2");
            _spineBone = FindBone(garmentRoot.transform, "spine", "spine1");
            _neckBone = FindBone(garmentRoot.transform, "neck");
            _leftUpperArmBone = FindBone(garmentRoot.transform, "leftupperarm", "l_upperarm", "leftarm");
            _rightUpperArmBone = FindBone(garmentRoot.transform, "rightupperarm", "r_upperarm", "rightarm");
            _leftLowerArmBone = FindBone(garmentRoot.transform, "leftlowerarm", "l_forearm", "leftforearm");
            _rightLowerArmBone = FindBone(garmentRoot.transform, "rightlowerarm", "r_forearm", "rightforearm");
        }

        public void ApplyPose(UnityPoseFrame poseFrame)
        {
            if (poseFrame == null || poseReceiver == null)
            {
                return;
            }

            var shoulderDir = BuildDirection(poseFrame.LeftShoulder, poseFrame.RightShoulder, Vector3.right);
            var spineDir = BuildDirection(poseFrame.HipCenter, poseFrame.ShoulderCenter, Vector3.up);

            var chestTarget = Quaternion.LookRotation(Vector3.forward, spineDir);
            var shoulderTilt = Mathf.Atan2(shoulderDir.y, shoulderDir.x) * Mathf.Rad2Deg;
            chestTarget *= Quaternion.Euler(0f, 0f, shoulderTilt * -0.65f);
            ApplyBoneRotation(_chestBone, chestTarget, chestRotationLerp, 10f);
            ApplyBoneRotation(_spineBone, chestTarget, chestRotationLerp * 0.8f, 8f);
            ApplyBoneRotation(_neckBone, chestTarget, chestRotationLerp * 0.6f, 6f);

            var leftUpperDir = BuildDirection(poseFrame.LeftShoulder, poseFrame.LeftElbow, shoulderDir);
            var rightUpperDir = BuildDirection(poseFrame.RightShoulder, poseFrame.RightElbow, shoulderDir);
            var leftLowerDir = BuildDirection(poseFrame.LeftElbow, poseFrame.LeftWrist, leftUpperDir);
            var rightLowerDir = BuildDirection(poseFrame.RightElbow, poseFrame.RightWrist, rightUpperDir);

            ApplyArmRotation(_leftUpperArmBone, leftUpperDir);
            ApplyArmRotation(_rightUpperArmBone, rightUpperDir);
            ApplyArmRotation(_leftLowerArmBone, leftLowerDir);
            ApplyArmRotation(_rightLowerArmBone, rightLowerDir);
        }

        private void ApplyArmRotation(Transform bone, Vector3 direction)
        {
            if (bone == null)
            {
                return;
            }

            var target = Quaternion.LookRotation(Vector3.forward, direction);
            ApplyBoneRotation(bone, target, armRotationLerp, maxArmRotationStep);
        }

        private static void ApplyBoneRotation(Transform bone, Quaternion target, float lerp, float maxStep)
        {
            if (bone == null)
            {
                return;
            }
            var stepped = Quaternion.RotateTowards(bone.localRotation, target, maxStep);
            bone.localRotation = Quaternion.Slerp(
                bone.localRotation,
                stepped,
                Mathf.Clamp01(lerp)
            );
        }

        private static Vector3 BuildDirection(UnityPosePoint from, UnityPosePoint to, Vector3 fallback)
        {
            if (from == null || to == null)
            {
                return fallback.normalized;
            }
            var dir = new Vector3(to.X - from.X, from.Y - to.Y, 0f);
            if (dir.sqrMagnitude < 0.0001f)
            {
                return fallback.normalized;
            }
            return dir.normalized;
        }

        private static Transform FindBone(Transform root, params string[] keywords)
        {
            if (root == null || keywords == null || keywords.Length == 0)
            {
                return null;
            }

            foreach (var node in root.GetComponentsInChildren<Transform>(true))
            {
                if (node == null)
                {
                    continue;
                }
                var lower = node.name.ToLowerInvariant();
                foreach (var key in keywords)
                {
                    if (lower.Contains(key))
                    {
                        return node;
                    }
                }
            }
            return null;
        }
    }
}

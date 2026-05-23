using System.Collections.Generic;
using UnityEngine;

namespace Abzora.TryOn
{
    public class GarmentClippingGuard : MonoBehaviour
    {
        [SerializeField] private PoseReceiver poseReceiver;
        [SerializeField] private float bodyColliderRadius = 0.09f;
        [SerializeField] private float bodyColliderHeight = 0.48f;
        [SerializeField] private float armColliderRadius = 0.055f;
        [SerializeField] private float armColliderHeight = 0.32f;
        [SerializeField] private float outwardOffset = 0.008f;

        private readonly List<CapsuleCollider> _colliders = new List<CapsuleCollider>();

        public void Setup(GameObject garmentRoot)
        {
            if (garmentRoot == null || poseReceiver == null)
            {
                poseReceiver = poseReceiver != null ? poseReceiver : GetComponent<PoseReceiver>();
                if (poseReceiver == null)
                {
                    return;
                }
            }

            _colliders.Clear();
            EnsureCollider(poseReceiver.ChestAnchor, "BodyClip_Chest", bodyColliderRadius, bodyColliderHeight, 1);
            EnsureCollider(poseReceiver.HipAnchor, "BodyClip_Hip", bodyColliderRadius * 1.04f, bodyColliderHeight, 1);
            EnsureCollider(poseReceiver.ShoulderLeftAnchor, "BodyClip_LeftArm", armColliderRadius, armColliderHeight, 1);
            EnsureCollider(poseReceiver.ShoulderRightAnchor, "BodyClip_RightArm", armColliderRadius, armColliderHeight, 1);

            var cloths = garmentRoot.GetComponentsInChildren<Cloth>(true);
            foreach (var cloth in cloths)
            {
                cloth.capsuleColliders = _colliders.ToArray();
                cloth.worldVelocityScale = 0.22f;
                cloth.worldAccelerationScale = 0.14f;
                cloth.friction = 0.5f;
            }

            garmentRoot.transform.localPosition += new Vector3(0f, 0f, outwardOffset);
        }

        private void EnsureCollider(Transform anchor, string name, float radius, float height, int direction)
        {
            if (anchor == null)
            {
                return;
            }

            var child = anchor.Find(name);
            if (child == null)
            {
                var go = new GameObject(name);
                child = go.transform;
                child.SetParent(anchor, false);
            }

            var collider = child.GetComponent<CapsuleCollider>();
            if (collider == null)
            {
                collider = child.gameObject.AddComponent<CapsuleCollider>();
            }

            collider.isTrigger = false;
            collider.direction = direction;
            collider.radius = Mathf.Max(0.01f, radius);
            collider.height = Mathf.Max(collider.radius * 2f, height);
            collider.center = Vector3.zero;
            _colliders.Add(collider);
        }
    }
}

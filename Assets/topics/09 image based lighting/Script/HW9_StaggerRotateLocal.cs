using UnityEngine;

public class HW9_StaggerRotateLocal : MonoBehaviour
{
    public enum Axis { X, Y, Z }

    [Header("Targets")]
    public bool useChildren = true;            // auto-collect children as targets
    public Transform[] targets;                // or assign manually in order

    [Header("Rotation")]
    public Axis axis = Axis.X;                 // choose local axis (X=red, Y=green, Z=blue)
    [Range(0f, 90f)] public float maxAngle = 50f;  // degrees ± around chosen axis

    [Header("Timing")]
    [Min(0.1f)] public float cycleDuration = 2.0f; // seconds -angle to +angle
    [Min(0f)] public float stagger = 0.35f;      // delay between neighbors
    public bool yoyo = true;                       // ping-pong
    public AnimationCurve ease = AnimationCurve.EaseInOut(0, 0, 1, 1);

    Quaternion[] _baseRot;

    void Awake()
    {
        if (useChildren)
        {
            int n = transform.childCount;
            targets = new Transform[n];
            for (int i = 0; i < n; ++i) targets[i] = transform.GetChild(i);
        }

        if (targets == null || targets.Length == 0) return;

        _baseRot = new Quaternion[targets.Length];
        for (int i = 0; i < targets.Length; ++i)
            _baseRot[i] = targets[i] ? targets[i].localRotation : Quaternion.identity;
    }

    void Update()
    {
        if (targets == null || targets.Length == 0 || _baseRot == null) return;

        Vector3 axisVec = (axis == Axis.X) ? Vector3.right :
                          (axis == Axis.Y) ? Vector3.up : Vector3.forward;

        for (int i = 0; i < targets.Length; ++i)
        {
            var t = targets[i];
            if (!t) continue;

            // staggered time
            float u = Mathf.Clamp01(Mathf.Repeat(Time.time - i * stagger, cycleDuration) / cycleDuration);
            float leg = yoyo ? PingPong01(u) : u;
            float k = ease.Evaluate(leg);
            float angle = Mathf.Lerp(-maxAngle, +maxAngle, k);

            t.localRotation = _baseRot[i] * Quaternion.AngleAxis(angle, axisVec);
        }
    }

    static float PingPong01(float x) => (x < 0.5f) ? (x * 2f) : (1f - (x - 0.5f) * 2f);

#if UNITY_EDITOR
    void OnDrawGizmosSelected()
    {
        if (!useChildren || transform.childCount == 0) return;
        Gizmos.color = Color.cyan;
        foreach (Transform t in transform)
        {
            if (!t) continue;
            Vector3 a = (axis == Axis.X) ? t.right :
                        (axis == Axis.Y) ? t.up : t.forward;
            Gizmos.DrawRay(t.position, a * 0.5f); // show chosen local axis
        }
    }
#endif
}

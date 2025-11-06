using UnityEngine;

public class HW9_StaggerRotateLocal : MonoBehaviour
{
    [Header("Targets")]
    public bool useChildren = true;            // auto-collect children as targets
    public Transform[] targets;                // or assign manually in order

    [Header("Motion")]
    [Min(0.1f)] public float cycleDuration = 2.0f;
    [Min(0f)] public float stagger = 0.35f;      // delay between neighbors (one-by-one)
    [Range(0f, 90f)] public float maxAngle = 50f;  // degrees around local X
    public AnimationCurve ease = AnimationCurve.EaseInOut(0, 0, 1, 1);
    public bool yoyo = true; // ping-pong

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

        for (int i = 0; i < targets.Length; ++i)
        {
            var t = targets[i];
            if (!t) continue;

            // time for this index (stagger makes them start one after another)
            float u = Mathf.Clamp01(Mathf.Repeat(Time.time - i * stagger, cycleDuration) / cycleDuration);
            float leg = yoyo ? PingPong01(u) : u;               // 0 to 1 (then back if yoyo)
            float k = ease.Evaluate(leg);                        // easing
            float angle = Mathf.Lerp(-maxAngle, +maxAngle, k);
            // rotate around local X (red axis)
            t.localRotation = _baseRot[i] * Quaternion.AngleAxis(angle, Vector3.right);
        }
    }

    // maps 0..1 over a full cycle to 0..1..0 (ping-pong)
    static float PingPong01(float x) => (x < 0.5f) ? (x * 2f) : (1f - (x - 0.5f) * 2f);
}

using UnityEngine;

public class HW9_BobUpDown : MonoBehaviour
{
    public enum TimeMode { BySpeed, ByDuration }
    public enum SpaceMode { World, Local }

    [Header("Path")]
    public SpaceMode space = SpaceMode.World;
    public Vector3 direction = Vector3.up;   // movement axis
    private float amplitude = 50.0f; // total distance from bottom to top

    [Header("Timing")]
    public TimeMode timeMode = TimeMode.ByDuration;
    [Min(0.01f)] public float speed = 1.0f;      // units per second (used if BySpeed)
    [Min(0.05f)] public float legDuration = 1.0f; // seconds from bottom->top (used if ByDuration)
    [Range(0f, 1f)] public float phase01 = 0f;   // start offset along the cycle
    public bool randomizePhaseOnStart = true;

    [Header("Style")]
    public AnimationCurve ease = AnimationCurve.EaseInOut(0, 0, 1, 1); // shape of the lerp
    public bool yoyo = true; // true = ping-pong, false = loop bottom->top only

    Vector3 _basePos;
    Vector3 _startPos;
    Vector3 _endPos;
    float _cycleLength; // seconds for a full bottom->top->bottom cycle

    void Awake()
    {
        _basePos = (space == SpaceMode.Local) ? transform.localPosition : transform.position;

        Vector3 dir = (space == SpaceMode.Local)
            ? (transform.rotation * direction.normalized) // orient local axis
            : direction.normalized;

        _startPos = _basePos - 0.5f * amplitude * dir;
        _endPos = _basePos + 0.5f * amplitude * dir;

        if (timeMode == TimeMode.BySpeed)
        {
            float leg = Mathf.Max(0.001f, amplitude) / Mathf.Max(0.001f, speed);
            _cycleLength = yoyo ? leg * 2f : leg;
        }
        else
        {
            _cycleLength = yoyo ? legDuration * 2f : legDuration;
        }

        if (randomizePhaseOnStart)
            phase01 = Random.value;

        // Place at initial phase
        UpdatePosition(Time.time + phase01 * _cycleLength);
    }

    void Update()
    {
        UpdatePosition(Time.time + phase01 * _cycleLength);
    }

    void UpdatePosition(float t)
    {
        if (_cycleLength <= 0.0001f) return;

        float u = Mathf.Repeat(t, _cycleLength) / _cycleLength; // [0,1) over full cycle

        // Map full-cycle u to a leg 0..1 with yoyo option
        float legT;
        if (yoyo)
        {
            // 0..0.5 going up, 0.5..1 going down
            if (u < 0.5f) legT = u * 2f;           // up   0->1
            else legT = 1f - (u - 0.5f) * 2f; // down 1->0
        }
        else
        {
            legT = u; // always 0->1 (then jumps back)
        }

        float k = ease.Evaluate(Mathf.Clamp01(legT));
        Vector3 p = Vector3.LerpUnclamped(_startPos, _endPos, k);

        if (space == SpaceMode.Local) transform.localPosition = transform.parent ? transform.parent.InverseTransformPoint(p) : p;
        else transform.position = p;
    }

}

using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(MeshRenderer))]
public class HW7_DropsDirector : MonoBehaviour
{
    // Spawn region in material UV space
    [Header("Spawn Area (UV)")]
    public Vector2 uvMin = new Vector2(0.25f, 0.35f);
    public Vector2 uvMax = new Vector2(0.75f, 0.75f);

    // First wave of drops at start
    [Header("Initial Burst")]
    [Range(1, 16)] public int initialDropsMin = 5;
    [Range(1, 16)] public int initialDropsMax = 8;
    public bool spawnSimultaneous = true;   // Same start time when true
    public float firstDelay = 0.10f;        // Delay before first wave
    public float staggerInterval = 0.35f;   // Gap between drops when staggered

    [Header("Per-drop Random Range")]
    [Min(0f)] public float baseRadiusMin = 0.010f; // Base radius min (UV units)
    [Min(0f)] public float baseRadiusMax = 0.022f; // Base radius max (UV units)
    [Min(0f)] public float expandSpeedMin = 0.070f; // Expansion speed min
    [Min(0f)] public float expandSpeedMax = 0.120f; // Expansion speed max
    public float anisoParallel = 2.00f;  // Faster along fiber direction
    public float anisoPerp = 0.40f;  // Slower across fiber direction

    [Header("Runtime")]
    public bool randomize = true; // Random positions when true; grid-like when false

    // Shader property IDs (cached)
    static readonly int ID_Count = Shader.PropertyToID("_DropCount");
    static readonly int ID_PosTime = Shader.PropertyToID("_DropPosTime");
    static readonly int ID_ParamsA = Shader.PropertyToID("_DropParamsA");

    // Single drop payload
    struct Drop
    {
        public Vector2 uv;         // Center in UV space
        public float baseR;        // Base radius
        public float expand;       // Expansion speed
        public float anisoPar;     // Anisotropy parallel to fiber
        public float anisoPerp;    // Anisotropy perpendicular to fiber
        public float seed;         // Noise seed (optional use)
        public float startTime;    // Start time in seconds
    }

    // Storage for active drops (max 16)
    readonly List<Drop> drops = new List<Drop>(16);

    // Material write buffer.
    MaterialPropertyBlock mpb;
    MeshRenderer mr;

    void Awake()
    {
        mr = GetComponent<MeshRenderer>();
        mpb = new MaterialPropertyBlock();
        mr.GetPropertyBlock(mpb);
    }

    void Start()
    {
        SpawnInitial();     // Create the first wave
        PushToMaterial();   // Upload to material once
    }

    // Create the initial set of drops
    void SpawnInitial()
    {
        drops.Clear();

        int count = Random.Range(initialDropsMin, initialDropsMax + 1);
        float t0 = Time.time + firstDelay;

        for (int i = 0; i < count; i++)
        {
            Drop d = new Drop();

            // Pick UV either random or evenly spaced
            d.uv = randomize
                ? new Vector2(Random.Range(uvMin.x, uvMax.x), Random.Range(uvMin.y, uvMax.y))
                : new Vector2(
                    Mathf.Lerp(uvMin.x, uvMax.x, (i + 1f) / (count + 1f)),
                    Mathf.Lerp(uvMin.y, uvMax.y, 0.5f)
                  );

            // Per-drop parameters from ranges
            d.baseR = Random.Range(baseRadiusMin, baseRadiusMax);
            d.expand = Random.Range(expandSpeedMin, expandSpeedMax);
            d.anisoPar = anisoParallel;
            d.anisoPerp = anisoPerp;
            d.seed = Random.value * 1000f;

            // Start time for each drop
            d.startTime = spawnSimultaneous ? t0 : (t0 + i * staggerInterval);

            drops.Add(d);
        }
    }

    // Add one drop at runtime
    public void TriggerDrop(Vector2 uv, bool startNow = true)
    {
        Drop d = new Drop
        {
            uv = uv,
            baseR = Random.Range(baseRadiusMin, baseRadiusMax),
            expand = Random.Range(expandSpeedMin, expandSpeedMax),
            anisoPar = anisoParallel,
            anisoPerp = anisoPerp,
            seed = Random.value * 1000f,
            startTime = startNow ? Time.time : (Time.time + firstDelay)
        };

        // Keep list within MAX_DROPS
        if (drops.Count >= 16) drops.RemoveAt(0);

        drops.Add(d);
        PushToMaterial();
    }

    // Write data to the material
    void PushToMaterial()
    {
        int n = Mathf.Min(16, drops.Count);

        // Pack arrays for shader StructuredBuffer-like vectors
        Vector4[] posTime = new Vector4[n]; // (ux, uy, baseR, startTime)
        Vector4[] paramsA = new Vector4[n]; // (anisoPar, anisoPerp, expand, seed)

        for (int i = 0; i < n; i++)
        {
            var d = drops[i];
            posTime[i] = new Vector4(d.uv.x, d.uv.y, d.baseR, d.startTime);
            paramsA[i] = new Vector4(d.anisoPar, d.anisoPerp, d.expand, d.seed);
        }

        mpb.SetInt(ID_Count, n);
        mpb.SetVectorArray(ID_PosTime, posTime);
        mpb.SetVectorArray(ID_ParamsA, paramsA);
        mr.SetPropertyBlock(mpb);
    }

    void Update()
    {
        // Spacebar spawns one extra drop
        if (Input.GetKeyDown(KeyCode.Space))
        {
            Vector2 uv = new Vector2(Random.Range(uvMin.x, uvMax.x), Random.Range(uvMin.y, uvMax.y));
            TriggerDrop(uv, true);
        }

        // Continuous push so startTime is respected by the shader
        PushToMaterial();
    }
}

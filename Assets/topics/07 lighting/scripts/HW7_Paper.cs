using UnityEngine;

[ExecuteAlways]
[RequireComponent(typeof(MeshFilter))]
[RequireComponent(typeof(MeshRenderer))]
public class HW7_Paper : MonoBehaviour
{
    // Grid resolution (higher = smoother mesh, but more verts)
    [Header("Grid")]
    public int xSegments = 80;
    public int ySegments = 48;

    // Paper size in meters
    [Header("Size")]
    public float width = 1.6f;
    public float height = 1.0f;

    // Simple shape controls
    [Header("Shape")]
    [Range(0f, 1f)] public float bend = 0.35f;  // Parabolic roll: center low
    [Range(0f, 0.1f)] public float rippleAmp = 0.025f; // Long ripples along Y
    [Range(0f, 6f)] public float rippleFreq = 2.2f;   // Ripple frequency
    [Range(0f, 0.1f)] public float noiseAmp = 0.018f; // Small random bumps

    // uv2.x = edge mask (stronger near left/right), uv2.y = ridge mask (sin along Y)
    Mesh _mesh;

    void OnEnable()
    {
        BuildOrUpdate();
    }

    void OnValidate()
    {
        // Rebuild in editor when parameters change
        BuildOrUpdate();
    }

    void OnDisable()
    {
        if (_mesh != null)
        {
            if (Application.isPlaying) Destroy(_mesh);
            else DestroyImmediate(_mesh);
            _mesh = null;
        }
    }

    void BuildOrUpdate()
    {
        var mf = GetComponent<MeshFilter>();
        if (_mesh == null)
        {
            _mesh = new Mesh { name = "PaperMesh" };
            mf.sharedMesh = _mesh;
        }
        BuildMesh(_mesh);
    }

    void BuildMesh(Mesh m)
    {
        int vx = xSegments + 1;
        int vy = ySegments + 1;
        int vcount = vx * vy;

        var verts = new Vector3[vcount];
        var norms = new Vector3[vcount];
        var uv0 = new Vector2[vcount];
        var uv2 = new Vector2[vcount];
        var tris = new int[xSegments * ySegments * 6];

        int id = 0;
        for (int iy = 0; iy <= ySegments; iy++)
        {
            float fy = iy / (float)ySegments; // 0..1
            for (int ix = 0; ix <= xSegments; ix++)
            {
                float fx = ix / (float)xSegments; // 0..1

                // Base rectangle centered at origin
                float X = (fx - 0.5f) * width;
                float Y = (fy - 0.5f) * height;
                float Z = 0f;

                // Parabolic roll across X
                float t = (fx - 0.5f) * 2f;       // -1..1
                Z += -0.5f * bend * t * t;

                // Long ripples + small noise
                Z += Mathf.Sin(fy * Mathf.PI * rippleFreq) * rippleAmp;
                Z += (Mathf.PerlinNoise(fx * 4.3f, fy * 4.1f) - 0.5f) * noiseAmp;

                // Masks for shader
                float edgeMask = Mathf.Pow(Mathf.InverseLerp(0.45f, 0.5f, Mathf.Abs(fx - 0.5f)), 1.15f);
                float ridgeMask = Mathf.Abs(Mathf.Sin(fy * Mathf.PI * rippleFreq));

                verts[id] = new Vector3(X, Y, Z);
                uv0[id] = new Vector2(fx, fy);
                uv2[id] = new Vector2(edgeMask, ridgeMask);
                norms[id] = Vector3.up;
                id++;
            }
        }

        // Triangle indices (row-major grid)
        int tId = 0;
        int stride = xSegments + 1;
        for (int y = 0; y < ySegments; y++)
        {
            for (int x = 0; x < xSegments; x++)
            {
                int a = y * stride + x;
                int b = (y + 1) * stride + x;
                int c = (y + 1) * stride + (x + 1);
                int d = y * stride + (x + 1);

                tris[tId++] = a; tris[tId++] = b; tris[tId++] = c;
                tris[tId++] = a; tris[tId++] = c; tris[tId++] = d;
            }
        }

        m.Clear();
        m.vertices = verts;
        m.normals = norms;    
        m.uv = uv0;
        m.uv2 = uv2;
        m.triangles = tris;
        m.RecalculateBounds();
    }
}

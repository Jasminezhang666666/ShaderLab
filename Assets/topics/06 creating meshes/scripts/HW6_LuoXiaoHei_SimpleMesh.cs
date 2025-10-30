using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(MeshFilter))]
[RequireComponent(typeof(MeshRenderer))]
public class HW6_LuoXiaoHei_3D_WithEarsAndTail : MonoBehaviour
{
    // Head
    public float headRadiusX = 0.55f, headRadiusY = 0.55f, headRadiusZ = 0.55f;

    // Body (superellipsoid)
    public float bodyHalfX = 0.55f, bodyHalfY = 0.55f, bodyHalfZ = 0.55f;
    public float n1 = 3.0f, n2 = 3.0f;   // larger = boxier
    public float neckGap = 0.03f;

    // Ears (triangular pyramid)
    public float earWidth = 0.2f, earDepth = 0.2f, earHeight = 0.2f;
    public float earSideOffset = 0.65f;

    // Tail
    public float tailLength = 1.2f;
    public float tailRadius = 0.05f;
    public float tailUpOffset = -0.1f;

    const int BODY_LAT = 24, BODY_LON = 36;
    const int HEAD_LAT = 32, HEAD_LON = 48;
    const int TAIL_SEGS = 16, TAIL_SIDES = 16;

    Mesh mesh;
    List<Vector3> vertices;
    List<Vector2> uv1s;      // x=tailT, y=ringAngleFraction(0..1)；非尾巴=0
    List<Color> colors;      // R=head, G=body, B=tail, A=earFlag
    List<int> triangles;

    void Start()
    {
        var mf = GetComponent<MeshFilter>();

        vertices = new List<Vector3>();
        uv1s = new List<Vector2>();
        colors = new List<Color>();
        triangles = new List<int>();

        mf.mesh = CreateCharacter();
    }

    Mesh CreateCharacter()
    {
        mesh = new Mesh { name = "HW6_LuoXiaoHei" };

        /*
        2D: (|x/a|)^(n) + (|y/b|)^(n) = 1
            n = 2 → perfect ellipse (round)
            n > 2 → gets squarer, but corners are still rounded

        3D: SignPow(t, p) = sign(t) * |t|^p
            If p < 1, values near 0 get larger → looks boxier.
            n = 2 -→ p = 1 (no change) → normal ellipsoid
        */


        // ===== BODY =====
        int bodyStart = vertices.Count;                 // remember where body verts begin
        float pow1 = 2f / Mathf.Max(n1, 1e-6f);        // control XY roundness: the signed-power exponent for XY "boxiness"
        float pow2 = 2f / Mathf.Max(n2, 1e-6f);        // control Z roundness

        for (int iv = 0; iv <= BODY_LAT; iv++)         // bottom to top rows
        {
            float v = Mathf.Lerp(-Mathf.PI * 0.5f, Mathf.PI * 0.5f, iv / (float)BODY_LAT); // Convert the row index into a vertical angle v in [-π/2, +π/2]
            float sv = Mathf.Sin(v), cv = Mathf.Cos(v);    // sin/cos of that vertical angle
            float svp = SignPow(sv, pow2), cvp = SignPow(cv, pow2); // Apply to make a super-ellipsoid Vertical profile

            for (int iu = 0; iu <= BODY_LON; iu++)     // columns
            {
                float u = Mathf.Lerp(0f, Mathf.PI * 2f, iu / (float)BODY_LON); // map to horizontal angle [0, 2pi]
                float su = Mathf.Sin(u), cu = Mathf.Cos(u); // sin/cos of horizontal angle
                float cup = SignPow(cu, pow1), sup = SignPow(su, pow1); 

                float x = bodyHalfX * cup * cvp;       // position x
                float y = bodyHalfY * sup * cvp;       // position y
                float z = bodyHalfZ * svp;             // position z

                vertices.Add(new Vector3(x, y, z));    // add vertex
                uv1s.Add(Vector2.zero);               
                colors.Add(new Color(0f, 1f, 0f, 0f)); // mark as BODY (G=1)
            }
        }
        AppendGridTriangles(triangles, bodyStart, BODY_LAT, BODY_LON); // connect body grid

        // ===== HEAD =====
        int headStart = vertices.Count;
        float bodyTopY = bodyHalfY; // top of body
        float headCenterY = bodyTopY + neckGap + headRadiusY;

        for (int iv = 0; iv <= HEAD_LAT; iv++) // head rows
        {
            float v = Mathf.Lerp(-Mathf.PI * 0.5f, Mathf.PI * 0.5f, iv / (float)HEAD_LAT);
            float sv = Mathf.Sin(v), cv = Mathf.Cos(v);

            for (int iu = 0; iu <= HEAD_LON; iu++)     // head columns
            {
                float u = Mathf.Lerp(0f, Mathf.PI * 2f, iu / (float)HEAD_LON);
                float su = Mathf.Sin(u), cu = Mathf.Cos(u);

                /*
                x = Rx * cos(v) * cos(u)
                y = Ry * sin(v)
                z = Rz * cos(v) * sin(u)
                */

                float x = headRadiusX * cv * cu;       // x
                float y = headRadiusY * sv + headCenterY; // y
                float z = headRadiusZ * cv * su;       // z

                vertices.Add(new Vector3(x, y, z)); 
                uv1s.Add(Vector2.zero);   
                colors.Add(new Color(1f, 0f, 0f, 0f)); // mark as HEAD (R=1)
            }
        }
        AppendGridTriangles(triangles, headStart, HEAD_LAT, HEAD_LON);

        // ===== EARS =====
        float headTopY = headCenterY + headRadiusY;    // top of head
        float baseY = headTopY;                        // ear base plane
        float side = earSideOffset * headRadiusX; // left/right offset

        AddTetraEar(new Vector3(+side, baseY, 0f), +1f, 0f); // left ear (A=0 = white)
        AddTetraEar(new Vector3(-side, baseY, 0f), -1f, 1f); // right ear (A=1 = black)

        // ===== TAIL (tube) =====
        int stride = TAIL_SIDES + 1; // verts per ring
        Vector3 tailRoot = new Vector3(0f, bodyHalfY * 0.6f + tailUpOffset, -bodyHalfZ); // Position where the tail attaches on the back

        int tailBase = vertices.Count;
        for (int s = 0; s <= TAIL_SEGS; s++) // along the tail
        {
            float t = s / (float)TAIL_SEGS; // 0..1 parameter from root to tip, “how far along the tail”
            Vector3 center = tailRoot + new Vector3(0, 0, -t * tailLength); // ring center

            for (int k = 0; k <= TAIL_SIDES; k++)      // around the ring
            {
                float ang = (k / (float)TAIL_SIDES) * Mathf.PI * 2f; // 0..2pi, the angle for the ring point.
                float cx = Mathf.Cos(ang), sx = Mathf.Sin(ang);      // (cx, sx) is a unit circle direction in the X–Y plane
                Vector3 p = center + new Vector3(cx * tailRadius, sx * tailRadius, 0f); // ring point

                vertices.Add(p);
                uv1s.Add(new Vector2(t, k / (float)TAIL_SIDES)); // uv1.x=tailT, uv1.y=angle fraction
                colors.Add(new Color(0f, 0f, 1f, 0f)); // mark as TAIL (B=1)
            }
        }
        //Two neighboring rings (rows) form a strip of quads. Each quad is split into two triangles
        for (int s = 0; s < TAIL_SEGS; s++)            // connect rings to quads → triangles
        {
            int row0 = tailBase + s * stride;
            int row1 = tailBase + (s + 1) * stride;
            for (int k = 0; k < TAIL_SIDES; k++)
            {
                int a = row0 + k;
                int b = row1 + k;
                int c = row1 + k + 1;
                int d = row0 + k + 1;
                triangles.Add(a); triangles.Add(b); triangles.Add(c);
                triangles.Add(a); triangles.Add(c); triangles.Add(d);
            }
        }

        // ===== push to Mesh =====
        mesh.vertices = vertices.ToArray();
        mesh.colors = colors.ToArray();
        mesh.uv2 = uv1s.ToArray();
        mesh.triangles = triangles.ToArray();
        mesh.RecalculateBounds(); 
        return mesh;

    }


    // ----- helpers -----
    void AddTetraEar(Vector3 c, float dirX, float earFlagA)
    {
        // base triangle on a horizontal plane through c.y
        Vector3 b0 = c + new Vector3(0f, 0f, +earDepth * 0.5f); // front point
        Vector3 b1 = c + new Vector3(-earWidth * 0.5f * dirX, 0f, -earDepth * 0.25f); // back-left
        Vector3 b2 = c + new Vector3(+earWidth * 0.5f * dirX, 0f, -earDepth * 0.25f); // back-right
        
        Vector3 a = c + new Vector3(0f, earHeight, 0f); // the tip above the base plane

        // 4 faces of a tetra (1 base + 3 sides)
        AddFace(b0, b1, b2, earFlagA); // base
        AddFace(a, b0, b1, earFlagA); // side 1
        AddFace(a, b1, b2, earFlagA); // side 2
        AddFace(a, b2, b0, earFlagA); // side 3
    }

    void AddFace(Vector3 v0, Vector3 v1, Vector3 v2, float earFlagA)
    {
        int i0 = vertices.Count; vertices.Add(v0); uv1s.Add(Vector2.zero); colors.Add(new Color(0f, 0f, 0f, earFlagA));
        int i1 = vertices.Count; vertices.Add(v1); uv1s.Add(Vector2.zero); colors.Add(new Color(0f, 0f, 0f, earFlagA));
        int i2 = vertices.Count; vertices.Add(v2); uv1s.Add(Vector2.zero); colors.Add(new Color(0f, 0f, 0f, earFlagA));
        triangles.Add(i0); triangles.Add(i1); triangles.Add(i2);
    }

    static float SignPow(float s, float p) => Mathf.Sign(s) * Mathf.Pow(Mathf.Abs(s), p);

    static void AppendGridTriangles(List<int> tris, int start, int lat, int lon)
    {
        int stride = lon + 1;

        for (int iv = 0; iv < lat; iv++)
            for (int iu = 0; iu < lon; iu++)
            {
                int a = start + iv * stride + iu;
                int b = start + (iv + 1) * stride + iu;
                int c = start + (iv + 1) * stride + (iu + 1);
                int d = start + iv * stride + (iu + 1);

                // two triangles per quad: a-b-c and a-c-d
                tris.Add(a); tris.Add(b); tris.Add(c);
                tris.Add(a); tris.Add(c); tris.Add(d);
            }
    }

    void OnDestroy()
    {
        if (mesh != null) Destroy(mesh);
    }
}

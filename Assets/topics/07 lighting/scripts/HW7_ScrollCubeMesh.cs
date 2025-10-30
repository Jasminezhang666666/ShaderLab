using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
[RequireComponent(typeof(MeshFilter))]
[RequireComponent(typeof(MeshRenderer))]
public class HW7_ScrollCubeMesh : MonoBehaviour
{
    [Header("Half Size (Object Space)")]
    public float halfX = 1.6f;   // 长
    public float halfY = 0.15f;  // 厚（薄一点像纸）
    public float halfZ = 0.40f;  // 宽

    [Header("Subdivision (simple)")]
    [Range(2, 256)] public int topSegX = 64;  // 顶面 X 细分（影响顶面扩散细节）
    [Range(2, 256)] public int topSegZ = 24;  // 顶面 Z 细分
    [Range(2, 256)] public int sideSegY = 48;  // 侧面竖向细分（影响“滴落”纵向细节）

    MeshFilter mf;
    MeshRenderer mr;
    Mesh mesh;

    void OnEnable()
    {
        mf = GetComponent<MeshFilter>();
        mr = GetComponent<MeshRenderer>();
        Rebuild();
    }

    void OnValidate()
    {
        halfX = Mathf.Max(0.01f, halfX);
        halfY = Mathf.Max(0.01f, halfY);
        halfZ = Mathf.Max(0.01f, halfZ);
        topSegX = Mathf.Max(2, topSegX);
        topSegZ = Mathf.Max(2, topSegZ);
        sideSegY = Mathf.Max(2, sideSegY);
        Rebuild();
    }

    void OnDisable()
    {
        if (!Application.isPlaying && mesh != null)
            DestroyImmediate(mesh);
    }

    void Rebuild()
    {
        if (mf == null) mf = GetComponent<MeshFilter>();
        if (mr == null) mr = GetComponent<MeshRenderer>();

        if (mesh == null)
        {
            mesh = new Mesh { name = "HW7_ScrollCube" };
            mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
        }
        else mesh.Clear();

        var vtx = new List<Vector3>();
        var nrm = new List<Vector3>();
        var uv = new List<Vector2>();
        var tri = new List<int>();

        // 顶面（细）
        BuildTop(vtx, nrm, uv, tri, topSegX, topSegZ);
        // 底面（粗一点即可）
        BuildBottom(vtx, nrm, uv, tri, Mathf.Max(2, topSegX / 4), Mathf.Max(2, topSegZ / 4));
        // 四个侧面（横向一条，竖向细分）
        BuildSideX(vtx, nrm, uv, tri, +1, 1, sideSegY); // +X
        BuildSideX(vtx, nrm, uv, tri, -1, 1, sideSegY); // -X
        BuildSideZ(vtx, nrm, uv, tri, +1, 1, sideSegY); // +Z
        BuildSideZ(vtx, nrm, uv, tri, -1, 1, sideSegY); // -Z

        mesh.SetVertices(vtx);
        mesh.SetNormals(nrm);
        mesh.SetUVs(0, uv);
        mesh.SetTriangles(tri, 0, true);
        mesh.RecalculateBounds();
        mf.sharedMesh = mesh;

        // 把半尺寸写回材质（供你的 HW7_Cube Shader 使用）
        if (mr.sharedMaterial != null)
        {
            var mpb = new MaterialPropertyBlock();
            mr.GetPropertyBlock(mpb);
            mpb.SetVector("_CubeSize", new Vector4(halfX, halfY, halfZ, 0));
            mr.SetPropertyBlock(mpb);
        }
    }

    // ===== 顶/底/侧 构建 =====
    void BuildTop(List<Vector3> vtx, List<Vector3> nrm, List<Vector2> uv, List<int> tri, int segX, int segZ)
    {
        float y = +halfY;
        int baseIdx = vtx.Count;

        for (int j = 0; j <= segZ; j++)
        {
            float tz = j / (float)segZ;
            float z = Mathf.Lerp(-halfZ, +halfZ, tz);
            for (int i = 0; i <= segX; i++)
            {
                float tx = i / (float)segX;
                float x = Mathf.Lerp(-halfX, +halfX, tx);

                vtx.Add(new Vector3(x, y, z));
                nrm.Add(Vector3.up);
                // 顶面 UV = XZ → [0,1] （匹配 HW7_Cube 的 TopUV 约定）
                uv.Add(new Vector2((x / (halfX * 2f)) + 0.5f, (z / (halfZ * 2f)) + 0.5f));
            }
        }
        AppendGrid(tri, baseIdx, segX, segZ, flip: false);
    }

    void BuildBottom(List<Vector3> vtx, List<Vector3> nrm, List<Vector2> uv, List<int> tri, int segX, int segZ)
    {
        float y = -halfY;
        int baseIdx = vtx.Count;

        for (int j = 0; j <= segZ; j++)
        {
            float tz = j / (float)segZ;
            float z = Mathf.Lerp(-halfZ, +halfZ, tz);
            for (int i = 0; i <= segX; i++)
            {
                float tx = i / (float)segX;
                float x = Mathf.Lerp(-halfX, +halfX, tx);

                vtx.Add(new Vector3(x, y, z));
                nrm.Add(Vector3.down);
                uv.Add(new Vector2((x / (halfX * 2f)) + 0.5f, (z / (halfZ * 2f)) + 0.5f));
            }
        }
        AppendGrid(tri, baseIdx, segX, segZ, flip: true); // 反面
    }

    void BuildSideX(List<Vector3> vtx, List<Vector3> nrm, List<Vector2> uv, List<int> tri, int signX, int segU, int segV)
    {
        float xFix = (signX >= 0) ? +halfX : -halfX;
        Vector3 normal = (signX >= 0) ? Vector3.right : Vector3.left;

        int baseIdx = vtx.Count;
        for (int v = 0; v <= segV; v++)
        {
            float ty = v / (float)segV;
            float y = Mathf.Lerp(+halfY, -halfY, ty); // 顶→底

            for (int u = 0; u <= segU; u++)
            {
                float tz = u / (float)segU;
                float z = Mathf.Lerp(-halfZ, +halfZ, tz);

                vtx.Add(new Vector3(xFix, y, z));
                nrm.Add(normal);
                // 侧面 UV：U=沿边（Z），V=顶→底（匹配 HW7_Cube 的 SideUV）
                uv.Add(new Vector2(tz, ty));
            }
        }
        AppendGrid(tri, baseIdx, segU, segV, flip: (signX < 0));
    }

    void BuildSideZ(List<Vector3> vtx, List<Vector3> nrm, List<Vector2> uv, List<int> tri, int signZ, int segU, int segV)
    {
        float zFix = (signZ >= 0) ? +halfZ : -halfZ;
        Vector3 normal = (signZ >= 0) ? Vector3.forward : Vector3.back;

        int baseIdx = vtx.Count;
        for (int v = 0; v <= segV; v++)
        {
            float ty = v / (float)segV;
            float y = Mathf.Lerp(+halfY, -halfY, ty);

            for (int u = 0; u <= segU; u++)
            {
                float tx = u / (float)segU;
                float x = Mathf.Lerp(-halfX, +halfX, tx);

                vtx.Add(new Vector3(x, y, zFix));
                nrm.Add(normal);
                // 侧面 UV：U=沿边（X），V=顶→底
                uv.Add(new Vector2(tx, ty));
            }
        }
        AppendGrid(tri, baseIdx, segU, segV, flip: (signZ < 0));
    }

    static void AppendGrid(List<int> tri, int start, int segU, int segV, bool flip)
    {
        int stride = segU + 1;
        for (int v = 0; v < segV; v++)
        {
            for (int u = 0; u < segU; u++)
            {
                int a = start + v * stride + u;
                int b = a + stride;
                int c = b + 1;
                int d = a + 1;
                if (!flip)
                {
                    tri.Add(a); tri.Add(b); tri.Add(c);
                    tri.Add(a); tri.Add(c); tri.Add(d);
                }
                else
                {
                    tri.Add(a); tri.Add(c); tri.Add(b);
                    tri.Add(a); tri.Add(d); tri.Add(c);
                }
            }
        }
    }
}
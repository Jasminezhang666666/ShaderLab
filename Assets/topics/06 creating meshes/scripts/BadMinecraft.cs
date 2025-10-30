using UnityEngine;
using System.Collections.Generic;
using UnityEngine.LowLevelPhysics;

[RequireComponent(typeof (MeshFilter))]
[RequireComponent(typeof (MeshRenderer))]
public class BadMinecraft : MonoBehaviour {

    Mesh mesh;
    List<Vector3> vertices;
    List<Vector3> normals;
    List<Vector2> uvs;
    List<int> triangles;
    
    
    void Start() {
       MeshFilter meshFilter = GetComponent<MeshFilter>();
       MeshRenderer meshRenderer = GetComponent<MeshRenderer>();
       
       vertices = new List<Vector3>();
       normals = new List<Vector3>();
       uvs = new List<Vector2>();
       triangles = new List<int>();

       meshFilter.mesh = CreateCube();
    }

    Mesh CreateCube() {
        mesh = new Mesh();
        float hs = 0.5f;
        
        // front face +z
        CreateQuad(
            new Vector3( hs, -hs,  hs),
            new Vector3( hs,  hs,  hs),
            new Vector3(-hs,  hs,  hs),
            new Vector3(-hs, -hs,  hs),
            new Vector3(0, 0, 1),
            new Vector2Int(0, 0)
            );
        
        // back face -z
        CreateQuad(
            new Vector3(-hs, -hs, -hs),
            new Vector3(-hs,  hs, -hs),
            new Vector3( hs,  hs, -hs),
            new Vector3( hs, -hs, -hs),
            new Vector3(0, 0, -1),
            new Vector2Int(0, 0)
        );
        
        // left face -x
        CreateQuad(
            new Vector3(-hs, -hs,  hs),
            new Vector3(-hs,  hs,  hs),
            new Vector3(-hs,  hs, -hs),
            new Vector3(-hs, -hs, -hs),
            new Vector3(-1, 0, 0),
            new Vector2Int(0, 0)
        );
        
        // right face +x
        CreateQuad(
            new Vector3( hs, -hs, -hs),
            new Vector3( hs,  hs, -hs),
            new Vector3( hs,  hs,  hs),
            new Vector3( hs, -hs,  hs),
            new Vector3(1, 0, 0),
            new Vector2Int(0, 0)
        );
        
        // top face +y
        CreateQuad(
            new Vector3(-hs,  hs, -hs),
            new Vector3(-hs,  hs,  hs),
            new Vector3( hs,  hs,  hs),
            new Vector3( hs,  hs, -hs),
            new Vector3(0, 1, 0),
            new Vector2Int(0, 1)
        );
        
        // bottom face -y
        CreateQuad(
            new Vector3( hs, -hs, -hs),
            new Vector3( hs, -hs,  hs),
            new Vector3(-hs, -hs,  hs),
            new Vector3(-hs, -hs, -hs),
            new Vector3(0, -1, 0),
            new Vector2Int(1, 0)
        );
        
        mesh.vertices = vertices.ToArray();
        mesh.normals = normals.ToArray();
        mesh.uv = uvs.ToArray();
        mesh.triangles = triangles.ToArray();
        
        return mesh;
    }

    void CreateQuad (Vector3 bl, Vector3 tl, Vector3 tr, Vector3 br, Vector3 normal, Vector2Int uvTile) {
        int startIndex = vertices.Count; // = 4

        vertices.Add(bl); // 0
        vertices.Add(tl); // 1
        vertices.Add(tr); // 2
        vertices.Add(br); // 3

        Vector3[] _normals = { normal, normal, normal, normal };
        normals.AddRange(_normals);

        Vector2 tilePos = new Vector2(uvTile.x, uvTile.y) * 0.5f;
        
        uvs.Add(new Vector2(0.0f + tilePos.x, 0.0f + tilePos.y)); // 0
        uvs.Add(new Vector2(0.0f + tilePos.x, 0.5f + tilePos.y)); // 1
        uvs.Add(new Vector2(0.5f + tilePos.x, 0.5f + tilePos.y)); // 2
        uvs.Add(new Vector2(0.5f + tilePos.x, 0.0f + tilePos.y)); // 3
        
        
        triangles.Add(startIndex + 0);
        triangles.Add(startIndex + 1);
        triangles.Add(startIndex + 2);
        
        triangles.Add(startIndex + 0);
        triangles.Add(startIndex + 2);
        triangles.Add(startIndex + 3);
    }

    void OnDestroy() {
        Destroy(mesh);
    }
    
}
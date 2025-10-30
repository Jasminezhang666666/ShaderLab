using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof (MeshFilter))]
[RequireComponent(typeof (MeshRenderer))]
public class ProceduralCube : MonoBehaviour {
    Mesh mesh;
    void Start() {
        MakeCube();
    }

    void MakeCube() {

        Vector3[] vertices = {
            new Vector3(0, 0, 0),
            new Vector3(1, 0, 0),
            new Vector3(1, 1, 0),
            new Vector3(0, 1, 0),
            new Vector3(0, 1, 1),
            new Vector3(1, 1, 1),
            new Vector3(1, 0, 1),
            new Vector3(0, 0, 1)
        };

        int[] triangles = {
            0, 3, 2, // south face ... -z
            0, 2, 1,
            3, 4, 5, // up face ... +y
            3, 5, 2,
            2, 5, 6, // east face ... +x
            2, 6, 1,
            7, 4, 3, // west face ... -x
            7, 3, 0,
            6, 5, 4, // north face ... +z
            6, 4, 7,
            7, 0, 1, // down face ... -y
            7, 1, 6
        };
        
        
        mesh = GetComponent<MeshFilter>().mesh;
        mesh.Clear();
        mesh.vertices = vertices;
        mesh.triangles = triangles;
    }


    void OnDestroy() {
        Destroy(mesh);   
    }
}
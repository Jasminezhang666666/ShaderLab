using UnityEngine;

[ExecuteInEditMode]
public class BakeSkyboxToCubemap : MonoBehaviour
{
    public RenderTexture targetCube; 
    void OnEnable()
    {
        if (targetCube != null)
            GetComponent<Camera>().RenderToCubemap(targetCube);
    }
}

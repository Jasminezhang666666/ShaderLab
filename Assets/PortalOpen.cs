using UnityEngine;

public class PortalOpen : MonoBehaviour
{
    [SerializeField] private float openDuration = 1f;   // seconds

    private Vector3 targetScale;

    private void Start()
    {
        targetScale = transform.localScale;

        transform.localScale = Vector3.zero;

        StartCoroutine(OpenPortal());
    }

    private System.Collections.IEnumerator OpenPortal()
    {
        float t = 0f;

        while (t < openDuration)
        {
            t += Time.deltaTime;
            float k = Mathf.Clamp01(t / openDuration);

            transform.localScale = Vector3.Lerp(Vector3.zero, targetScale, k);

            yield return null;
        }

        // Ensure exact final scale
        transform.localScale = targetScale;
    }
}

Shader "shader lab/week 10/funhouse_verticalStretch"
{
    Properties
    {
        // How much the middle is stretched vs top/bottom
        _MiddleStretch ("middle stretch amount", Range(0, 1)) = 0.5
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }

        Cull Off
        ZWrite Off
        ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_BlitTexture);
            SAMPLER(sampler_BlitTexture);

            CBUFFER_START(UnityPerMaterial)
            float _MiddleStretch;
            CBUFFER_END

            struct MeshData
            {
                uint vertexID : SV_VertexID;
            };

            struct Interpolators
            {
                float4 posCS : SV_POSITION;
                float2 uv    : TEXCOORD0;
            };

            // Fullscreen triangle vertex
            Interpolators vert (MeshData v)
            {
                Interpolators o;
                o.posCS = GetFullScreenTriangleVertexPosition(v.vertexID);
                o.uv    = GetFullScreenTriangleTexCoord(v.vertexID);
                return o;
            }

            float4 frag (Interpolators i) : SV_Target
            {
                float2 uv = i.uv;

                // Work with a vertical coordinate centered at 0
                float y = uv.y;
                float centered = y - 0.5f;      // [-0.5, 0.5]

                // Normalized distance from the center in [-1,1]
                float t = centered / 0.5f;      // [-1,1]

                // |t| == 0 at center, 1 at top/bottom
                float dist = abs(t);

                // center: stretched
                // top/bottom: squashed
                // Create a scale factor that is large near center, and smaller near edges
                float scaleCenter = 1.0 + _MiddleStretch;
                float scaleEdge   = 1.0 - _MiddleStretch;

                // Smoothly interpolate between center and edges
                float scale = lerp(scaleCenter, scaleEdge, dist);

                // Apply the scale in "centered" space
                float newCentered = centered * scale;

                // Back to [0,1] UV space
                float newY = 0.5f + newCentered;

                // clamp
                newY = clamp(newY, 0.001f, 0.999f);

                float2 warpedUV = float2(uv.x, newY);

                float3 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, warpedUV).rgb;
                return float4(color, 1.0);
            }

            ENDHLSL
        }
    }
}

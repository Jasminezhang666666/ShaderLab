Shader "shader lab/week 10/funhouse_vortex"
{
    Properties
    {
        // How strong the twist is near the center
        _SwirlStrength ("swirl strength", Range(0, 10)) = 4.0

        // How far from the center the swirl reaches
        _SwirlRadius   ("swirl radius", Range(0.1, 1))  = 0.6
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
            float _SwirlStrength;
            float _SwirlRadius;
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

                // Center the coordinates around (0,0)
                float2 center = float2(0.5, 0.5);
                float2 d      = uv - center;

                // Distance from the center
                float r = length(d);

                // If outside swirl radius, just sample normally
                if (r > _SwirlRadius)
                {
                    float3 col = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv).rgb;
                    return float4(col, 1.0);
                }

                // "Falloff" of the swirl: 1.0 at center, 0 at swirl radius
                float t = 1.0 - saturate(r / _SwirlRadius);

                // Angle to rotate by: more twist near the center
                float angle = _SwirlStrength * t * t;  // t^2 for smoother center

                // Rotate the vector d by angle
                float s = sin(angle);
                float c = cos(angle);

                float2 dRot;
                dRot.x = c * d.x - s * d.y;
                dRot.y = s * d.x + c * d.y;

                // Back to UV space
                float2 swirlUV = center + dRot;

                // clamp
                swirlUV = clamp(swirlUV, float2(0.001, 0.001), float2(0.999, 0.999));

                float3 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, swirlUV).rgb;
                return float4(color, 1.0);
            }

            ENDHLSL
        }
    }
}

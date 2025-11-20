Shader "shader lab/week 11/portalSky_HW11"
{
    Properties
    {
        _cubeMap   ("universe cubemap", Cube) = "white" {}
        _colorA    ("tint A", Color)  = (1, 1, 1, 1)
        _colorB    ("tint B", Color)  = (1, 1, 1, 1)
        _stencilRef ("stencil reference", Int) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "Queue"          = "Transparent"
        }

        ZWrite Off
        ZTest LEqual
        Cull Front

        Stencil
        {
            Ref      [_stencilRef]   // 1
            Comp     Equal
            ReadMask 1               // only care about bit 0
        }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float3 _colorA;
            float3 _colorB;
            CBUFFER_END

            TEXTURECUBE(_cubeMap);
            SAMPLER(sampler_cubeMap);

            struct MeshData
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct Interpolators
            {
                float4 vertex   : SV_POSITION;
                float3 objPos   : TEXCOORD0;
            };

            Interpolators vert (MeshData v)
            {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.objPos = v.vertex.xyz;
                return o;
            }

            float get_luminance (float3 c)
            {
                float3 w = float3(0.2126, 0.7152, 0.0722);
                return dot(c, w);
            }

            float4 frag (Interpolators i) : SV_Target
            {
                float3 dir    = normalize(i.objPos);
                float3 skyCol = SAMPLE_TEXTURECUBE(_cubeMap, sampler_cubeMap, dir);

                float  lum    = get_luminance(skyCol);
                int    steps  = 8;
                lum = floor(lum * steps) / steps;
                float3 baseColor = lerp(_colorA, _colorB, lum) * skyCol;

                return float4(baseColor, 1.0);
            }
            ENDHLSL
        }
    }
}

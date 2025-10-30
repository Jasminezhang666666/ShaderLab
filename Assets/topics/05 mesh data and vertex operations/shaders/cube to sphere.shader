Shader "shader lab/week 5/cube to sphere" {
    Properties {
        _radius ("radius", Float) = 5
        _morph ("morph", Range(0,1)) = 0
    }

    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float _radius;
            float _morph;
            CBUFFER_END

            struct MeshData {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD0;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.normal = v.normal;
                v.vertex.xyz = lerp(v.vertex.xyz, normalize(v.vertex.xyz) * _radius, _morph);
                o.vertex = TransformObjectToHClip(v.vertex);

                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                return float4(abs(i.normal.rgb), 1.0);
            }
            ENDHLSL
        }
    }
}
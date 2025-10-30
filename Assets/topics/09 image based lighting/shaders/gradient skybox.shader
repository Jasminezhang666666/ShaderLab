Shader "shader lab/week 9/gradient skybox" {
    Properties {
        _colorHigh ("color high", Color) = (1, 1, 1, 1)
        _colorLow ("color low", Color) = (0, 0, 0, 1)
        _offset ("offset", Range(0, 1)) = 0
        _contrast ("contrast", Float) = 1
    }

    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Background"
            "RenderType" = "Background"
            "PreviewType" = "Skybox"
        }
        
        Cull Off
        ZWrite Off

        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float3 _colorHigh;
            float3 _colorLow;
            float _offset;
            float _contrast;
            CBUFFER_END

            struct MeshData {
                float4 vertex : POSITION;
                float3 uv : TEXCOORD0;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float3 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                float3 color = 0;
                float3 coord = normalize(i.uv) * 0.5 + 0.5;
                color = coord;
                
                color = lerp(_colorLow, _colorHigh, pow(coord.y + _offset, _contrast));

                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
Shader "shader lab/week 12/texture sdf" {
    Properties {
        [NoScaleOffset]_tex ("texture", 2D) = "white" {}
        _color ("color", Color) = (0, 0, 0, 0)
        _threshold ("threshold", Range(0,1)) = 0.5
        _softness ("softness", Range(0,1)) = 0
        _outlineThresdhold ("outline threshold", Range(0,1)) = 0
    }
    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"="Transparent"
            "Queue" = "Transparent"
        }

        Blend SrcAlpha OneMinusSrcAlpha

        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _color;
            float _threshold;
            float _softness;
            float _outlineThresdhold;
            CBUFFER_END

            TEXTURE2D(_tex);
            SAMPLER(sampler_tex);
            
            struct MeshData {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                float3 color = 0;

                float4 df = SAMPLE_TEXTURE2D(_tex, sampler_tex, i.uv);

                float shape = smoothstep(_threshold, _threshold + _softness, df);
                float outline = smoothstep(_outlineThresdhold, _outlineThresdhold + _softness, df);

                
                color = outline;
                
                return float4(color * _color, shape);
            }
            ENDHLSL
        }
    }
}
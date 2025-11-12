Shader "shader lab/week 10/dither" {
    Properties{
        _ditherPattern ("dither pattern", 2D) = "gray" {}
        _threshold ("threshold", Range(-1, 1)) = 0
    }
    SubShader {
        Tags { "RenderPipeline"="UniversalPipeline" }
        
        ZWrite Off
        Cull Off
        ZTest Always
        
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _BlitTexture_TexelSize; // (1/width, 1/height, width, height)
            float4 _ditherPattern_TexelSize;
            float _threshold;
            CBUFFER_END

            TEXTURE2D(_BlitTexture);
            SAMPLER(sampler_BlitTexture);

            TEXTURE2D(_ditherPattern);
            
            struct MeshData {
                uint vertexID : SV_VertexID;
            };
            
            struct Interpolators {
                float4 posCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            
            Interpolators vert (MeshData v) {
                Interpolators o;
                o.posCS = GetFullScreenTriangleVertexPosition(v.vertexID);
                o.uv    = GetFullScreenTriangleTexCoord   (v.vertexID);
                return o;
            }

            float get_luminance (float3 color) {
                float3 channelWeight = float3(0.2126, 0.7152, 0.0722);
                return dot(color, channelWeight);
            }
            
            float4 frag (Interpolators i) : SV_Target {
                float2 uv = i.uv;
                float color = 0;

                

                color = get_luminance(SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv));


                // example: (1 / 128) * 256 = 2 
                float2 ditherUV = (uv / _ditherPattern_TexelSize.zw) * _BlitTexture_TexelSize.zw;
                float dither = SAMPLE_TEXTURE2D(_ditherPattern, sampler_PointRepeat, ditherUV);
                
                color = step(dither, color + _threshold);
                
                return float4(color.rrr, 1.0);
            }
            ENDHLSL
        }
    }
}
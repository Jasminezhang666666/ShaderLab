Shader "shader lab/week 10/two pass blur" {
    Properties {
        
    }
    SubShader {
        Tags { "RenderPipeline"="UniversalPipeline" }
        
        Cull Off
        ZWrite Off
        ZTest Always
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _BlitTexture_TexelSize;
        CBUFFER_END

        TEXTURE2D(_BlitTexture);
        SAMPLER(sampler_BlitTexture);
        
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
            o.uv    = GetFullScreenTriangleTexCoord(v.vertexID);
            return o;
        }
        ENDHLSL
        
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            float4 frag (Interpolators i) : SV_Target {
                half4 sum = 0;
                
				return sum;
            }
            ENDHLSL
        }

        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            float4 frag (Interpolators i) : SV_Target {
                half4 sum = 0;
                
				return sum;
            }
            ENDHLSL
        }
    }
}
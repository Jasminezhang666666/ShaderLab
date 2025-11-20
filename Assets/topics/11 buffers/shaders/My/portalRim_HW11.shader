Shader "shader lab/week 11/portalRim_HW11"
{
    Properties
    {
        _rimColor ("rim color", Color) = (1, 0.8, 0.2, 1)
        _rimPower ("rim power", Range(1, 8)) = 3
        _rimIntensity ("rim intensity", Range(0, 5)) = 1
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
        Cull Back      // outside this small sphere, so backfaces are hidden

        Blend One One  // additive glow

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _rimColor;
            float  _rimPower;
            float  _rimIntensity;
            CBUFFER_END

            struct MeshData
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct Interpolators
            {
                float4 vertex   : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            Interpolators vert (MeshData v)
            {
                Interpolators o;
                o.vertex   = TransformObjectToHClip(v.vertex);
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                o.worldPos = TransformObjectToWorld(v.vertex).xyz;
                return o;
            }

            float4 frag (Interpolators i) : SV_Target
            {
                float3 N = normalize(i.normalWS);
                float3 V = normalize(GetCameraPositionWS() - i.worldPos);

                float ndotv = saturate(dot(N, V));
                float rim   = pow(1.0 - ndotv, _rimPower);

                rim *= _rimIntensity;

                float3 color = rim * _rimColor.rgb;

                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}

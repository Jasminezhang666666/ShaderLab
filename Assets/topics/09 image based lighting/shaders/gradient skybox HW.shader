Shader "shader lab/week 9/gradient skybox HW"
{
    Properties
    {
        // Vertical (bottom→top)
        _BottomColor ("Bottom Color", Color) = (0.08, 0.02, 0.20, 1)
        _MidColor    ("Mid  Color",   Color) = (0.95, 0.10, 0.65, 1)
        _TopColor    ("Top    Color", Color) = (0.00, 0.75, 1.00, 1)
        _HorizonCenter ("Horizon Center", Range(-0.5,0.5)) = 0.0
        _HorizonSoft  ("Horizon Softness", Range(0.05, 2)) = 0.5

        // Diagonal sweep (two-color ramp projected on a tilted axis)
        _DiagA ("Diagonal A", Color) = (1.00, 0.30, 0.20, 1)
        _DiagB ("Diagonal B", Color) = (0.10, 0.30, 1.00, 1)
        _DiagAngleDeg ("Diagonal Angle (deg)", Range(0,180)) = 35
        _DiagWeight   ("Diagonal Mix", Range(0,1)) = 0.35

        // Radial ring / sun glow around a direction
        _SunYawDeg   ("Sun Yaw (deg)", Range(0,360)) = 30
        _SunPitchDeg ("Sun Pitch (deg)", Range(-89,89)) = 15
        _RingColor   ("Ring Color", Color) = (1.00, 0.95, 0.35, 1)
        _RingRadius  ("Ring Radius (deg)", Range(1,60)) = 18
        _RingSoft    ("Ring Softness", Range(0.2, 30)) = 8
        _RingWeight  ("Ring Mix", Range(0,1)) = 0.45

        // Global controls
        _Saturation  ("Global Saturation", Range(0,1.5)) = 1.0
        _Quantize    ("Color Bands (0=off, up to ~8)", Range(0,8)) = 0
        _Exposure    ("Exposure", Range(0.2,2.5)) = 1.0
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "Queue"="Background"
            "RenderType"="Background"
            "PreviewType"="Skybox"
        }

        Cull Off
        ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _BottomColor, _MidColor, _TopColor;
            float  _HorizonCenter, _HorizonSoft;

            float4 _DiagA, _DiagB;
            float  _DiagAngleDeg, _DiagWeight;

            float  _SunYawDeg, _SunPitchDeg;
            float4 _RingColor;
            float  _RingRadius, _RingSoft, _RingWeight;

            float  _Saturation, _Quantize, _Exposure;
            CBUFFER_END

            struct VSIn  { float4 vertex : POSITION; };
            struct VSOut { float4 pos : SV_POSITION; float3 dirWS : TEXCOORD0; };

            VSOut vert (VSIn v)
            {
                VSOut o;
                o.pos = TransformObjectToHClip(v.vertex);
                // For a skybox mesh centered at origin, object position is ray direction
                o.dirWS = normalize(v.vertex.xyz);
                return o;
            }

            // helpers
            float3 saturateColor(float3 c, float s){
                float g = dot(c, float3(0.299,0.587,0.114));
                return lerp(g.xxx, c, s);
            }
            float3 quantize(float3 c, float steps){ return (steps<=0.0)? c : floor(c*steps)/steps; }

            // build unit vectors from yaw/pitch
            float3 dirFromYawPitch(float yawDeg, float pitchDeg){
                float yaw = radians(yawDeg);
                float pit = radians(pitchDeg);
                float cy = cos(yaw), sy = sin(yaw);
                float cp = cos(pit), sp = sin(pit);
                // Y up
                return normalize(float3(cp*cy, sp, cp*sy));
            }

            float4 frag (VSOut i) : SV_Target
            {
                float3 dir = normalize(i.dirWS);   // world-space direction, Y is up

                // --- 1) Vertical tri-gradient with a smoother horizon band
                // remap Y to [0,1] with center & softness
                float t = saturate((dir.y - _HorizonCenter) / max(_HorizonSoft, 1e-3) * 0.5 + 0.5);
                float3 vertCol = lerp(_BottomColor.rgb, _TopColor.rgb, t);
                // blend a middle color around horizon
                float midMask = exp(-pow((dir.y - _HorizonCenter) * 2.2 / max(_HorizonSoft, 1e-3), 2));
                vertCol = lerp(vertCol, _MidColor.rgb, midMask);

                // --- 2) Diagonal sweep (project on a tilted axis in XZ plane)
                float ang = radians(_DiagAngleDeg);
                float3 axis = normalize(float3(cos(ang), 0, sin(ang))); // horizontal axis
                float td = saturate(dot(dir, axis) * 0.5 + 0.5);
                float3 diagCol = lerp(_DiagA.rgb, _DiagB.rgb, smoothstep(0.0,1.0,td));
                float3 baseCol = lerp(vertCol, diagCol, _DiagWeight);

                // --- 3) Radial ring/sun around a direction
                float3 sunDir = dirFromYawPitch(_SunYawDeg, _SunPitchDeg);
                float angToSun = degrees(acos(saturate(dot(dir, sunDir))));
                float ring = exp(-pow( (angToSun - _RingRadius) / max(_RingSoft,1e-3), 2));
                float3 ringed = lerp(baseCol, baseCol + _RingColor.rgb, ring * _RingWeight);

                // post: saturation, quantize bands, exposure
                float3 col = ringed;
                col = saturateColor(col, _Saturation);
                col = quantize(col, _Quantize > 0.5 ? round(_Quantize) : 0.0);
                col *= _Exposure;

                return float4(col, 1);
            }
            ENDHLSL
        }
    }
}

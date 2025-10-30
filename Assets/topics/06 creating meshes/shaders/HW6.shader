Shader "shader lab/week 6/HW6"
{
    Properties
    {
        _HeadColor     ("Head Color", Color) = (0,0,0,1)
        _BodyColor     ("Body Color", Color) = (1,1,1,1)
        _TailColor     ("Tail Color", Color) = (0,0,0,1)
        _EarLeftColor  ("Left Ear Color", Color) = (1,1,1,1)
        _EarRightColor ("Right Ear Color", Color) = (0,0,0,1)

        _TailAmp   ("Tail Amplitude (units)", Float) = 0.18
        _TailFreq  ("Tail Frequency (Hz)",   Float) = 0.8
        _TailPhase ("Tail Wave Phase",       Float) = 6.283185
        _TailTaper ("Tail Tip Power",        Float) = 1.5
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Geometry" }
        Pass
        {
            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #define PI 3.14159265359
            #define PIN_EPS 0.02    // small angle window to pin exactly one root vertex

            // Per-vertex inputs
            struct MeshData
            {
                float4 vertex : POSITION;
                float4 color  : COLOR;     // R=head, G=body, B=tail, A=earFlag (0=left,1=right)
                float2 uv1    : TEXCOORD1; // x=tailT (0..1), y=ringAngleFraction (0..1)
            };

            // Interpolators to the fragment shader
            struct V2F
            {
                float4 posCS : SV_POSITION;
                float4 color : COLOR;
            };

            // Material parameters
            CBUFFER_START(UnityPerMaterial)
            float4 _HeadColor, _BodyColor, _TailColor, _EarLeftColor, _EarRightColor;
            float  _TailAmp, _TailFreq, _TailPhase, _TailTaper;
            CBUFFER_END

            V2F vert (MeshData v)
            {
                float4 posOS = v.vertex;

                // Tail sway (only tail moves; pin one root vertex)
                float isTail  = step(0.5, v.color.b);     // 1 if B>0.5 (tail), else 0
                float tailT   = v.uv1.x;                  // 0 at root → 1 at tip
                float angFrac = frac(saturate(v.uv1.y));  // 0..1 around the ring

                // Pin mask = 1 for the single root vertex at angle≈0; 0 otherwise
                float pinMask = step(tailT, 1e-6) * step(angFrac, PIN_EPS);
                float moveMask = isTail * (1.0 - pinMask);

                // Sine motion in X; amplitude grows toward the tip; phase scrolls along length
                float w     = 2.0 * PI * _TailFreq;
                float phase = _TailPhase * tailT;
                float amp   = _TailAmp * pow(saturate(tailT), max(_TailTaper, 0.0));

                posOS.x += moveMask * sin(w * _Time.y + phase) * amp;

                V2F o;
                o.posCS = TransformObjectToHClip(posOS.xyz);
                o.color = v.color; // carry part mask to the fragment stage
                return o;
            }

            float4 frag (V2F i) : SV_Target
            {
                // Solid color by part mask (priority: head > body > tail > ears)
                if (i.color.r > 0.5) return _HeadColor;             // head (black)
                if (i.color.g > 0.5) return _BodyColor;             // body (white)
                if (i.color.b > 0.5) return _TailColor;             // tail (black)
                // ears: use alpha to choose left/right color
                return (i.color.a > 0.5) ? _EarRightColor : _EarLeftColor;
            }
            ENDHLSL
        }
    }
}

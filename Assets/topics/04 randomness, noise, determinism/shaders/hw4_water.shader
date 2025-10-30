Shader "shader lab/week 4/hw4_water_min"
{
    Properties
    {
        _BlueTex        ("Blue Height/Normal-like Texture", 2D) = "white" {}

        // Base tint
        _Tint           ("Base Tint (multiply)", Color) = (0.25, 0.60, 0.90, 1)
        _Tint2          ("Tint 2 (nearby color)", Color) = (0.18, 0.70, 0.95, 1)
        _Tint3          ("Tint 3 (nearby color)", Color) = (0.20, 0.50, 0.80, 1)
        _VarAmount      ("Color variation amount", Range(0,1)) = 0.55

        // Drift & waves
        _DriftSpeed     ("Drift speed (uv/sec)", Float) = 0.15
        _DriftAngleDeg  ("Drift angle (deg)", Range(-180,180)) = 0
        _TravelAngleDeg ("Wave travel angle (deg)", Range(-180,180)) = 90
        _Wave1Amp       ("Wave1 amplitude (uv)", Range(0, 0.2)) = 0.035
        _Wave1Freq      ("Wave1 frequency", Range(0.1, 30))     = 8
        _Wave1Speed     ("Wave1 speed", Range(0, 10))           = 2.0
        _Wave2Amp       ("Wave2 amplitude (uv)", Range(0, 0.2)) = 0.015
        _Wave2Freq      ("Wave2 frequency", Range(0.1, 30))     = 15
        _Wave2Speed     ("Wave2 speed", Range(0, 10))           = 3.2
        _Wave2PhaseOff  ("Wave2 phase offset", Range(0, 6.28318)) = 1.2

        // Specular
        _SunColor       ("Sun/spec color", Color) = (1,1,1,1)
        _SpecStrength   ("Specular strength", Range(0,1.5)) = 0.5

        // Crest detection thresholds
        _SlopeThr       ("Slope threshold", Range(0,1)) = 0.20
        _CurveThr       ("Curvature threshold", Range(0,1)) = 0.10
        _BandSoft       ("Crest band softness", Range(0.01,0.5)) = 0.16

        // Depth absorption
        _AbsorbColor    ("Deep absorption color", Color) = (0.0, 0.25, 0.35, 1)
        _AbsorbStrength ("Absorb amount", Range(0,2)) = 0.6
        _AbsorbStartEnd ("Absorb start(y), end(y)", Vector) = (0.25, 0.95, 0, 0)

        // Simple tone
        _Contrast       ("Contrast", Range(0.5, 2.0)) = 1.0
        _Brightness     ("Brightness", Range(0.0, 2.0)) = 1.0
        _ShadowLift     ("Shadow lift", Range(0,0.3)) = 0.05
        _HighlightBoost ("Highlight boost", Range(0,1)) = 0.35
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" }
        Pass
        {
            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _Tint, _Tint2, _Tint3;
                float  _VarAmount;

                float  _DriftSpeed, _DriftAngleDeg;
                float  _TravelAngleDeg;
                float  _Wave1Amp, _Wave1Freq, _Wave1Speed;
                float  _Wave2Amp, _Wave2Freq, _Wave2Speed, _Wave2PhaseOff;

                float4 _SunColor;
                float  _SpecStrength;

                float  _SlopeThr, _CurveThr, _BandSoft;

                float4 _AbsorbColor, _AbsorbStartEnd;
                float  _AbsorbStrength;

                float  _Contrast, _Brightness, _ShadowLift, _HighlightBoost;
            CBUFFER_END

            TEXTURE2D(_BlueTex);
            SAMPLER(sampler_BlueTex);
            float4 _BlueTex_ST;

            // ---- helpers ----
            float rand (float2 uv) { return frac(sin(dot(uv, float2(12.9898,78.233))) * 43758.5453123); }

            float value_noise (float2 uv)
            {
                float2 ip=floor(uv), fp=frac(uv);
                float o=rand(ip), x=rand(ip+float2(1,0)), y=rand(ip+float2(0,1)), xy=rand(ip+float2(1,1));
                float2 s=smoothstep(0,1,fp);
                return lerp( lerp(o,x,s.x), lerp(y,xy,s.x), s.y );
            }

            // color variation 
            float fbm (float2 uv)
            {
                float n=0;
                n += 0.5   * value_noise(uv);
                n += 0.25  * value_noise(uv*2);
                n += 0.125 * value_noise(uv*4);
                n += 0.0625* value_noise(uv*8);
                return n;
            }

            //Rotates a 2D vector by radians
            float2 rot(float2 v, float rad){ float s=sin(rad), c=cos(rad); return float2(c*v.x - s*v.y, s*v.x + c*v.y); }
            //contrast/brightness
            float3 tone(float3 c, float con, float bri){ c=(c-0.5)*con+0.5; c*=bri; return c; }

            struct MeshData {
            float4 vertex : POSITION;
            float2 uv     : TEXCOORD0;
        };

        struct Interpolators {
            float4 vertex : SV_POSITION;
            float2 uv     : TEXCOORD0;
        };

        Interpolators vert (MeshData v) {
            Interpolators o;
            o.vertex = TransformObjectToHClip(v.vertex);
            o.uv     = TRANSFORM_TEX(v.uv, _BlueTex);
            return o;
        }

            float4 frag (Interpolators i) : SV_Target
            {
                const float VAR_SCALE   = 10.0;  // color variation scale
                const float SPEC_POWER  = 48.0;  // highlight specular sharpness
                const float NORMAL_Z    = 1.0;   // fake normal Z scale

                float  t   = _Time.y;

                // Base UV with slow drift
                float2 baseUV = i.uv;
                float2 uv = baseUV + rot(float2(1,0), radians(_DriftAngleDeg)) * (_DriftSpeed * t);

                // Waves (stripes perpendicular to travel direction)
                float2 travelDir = rot(float2(1,0), radians(_TravelAngleDeg)); //perpendicular to travel
                float2 crestDir  = float2(-travelDir.y, travelDir.x);
                float  phase1    = dot(uv, travelDir) * _Wave1Freq - t * _Wave1Speed;
                float  phase2    = dot(uv, travelDir) * _Wave2Freq - t * _Wave2Speed + _Wave2PhaseOff;
                uv += _Wave1Amp * sin(phase1) * crestDir;
                uv += _Wave2Amp * sin(phase2) * crestDir;

                // Base texture
                float3 baseRGB = SAMPLE_TEXTURE2D(_BlueTex, sampler_BlueTex, uv).rgb;

                // Gentle color variation
                float  p = saturate( fbm( uv * VAR_SCALE ) );
                float  m = smoothstep(0.3, 0.7, p);
                float3 tintMix = lerp(_Tint2.rgb, _Tint3.rgb, m);
                float3 tint    = lerp(_Tint.rgb,  tintMix, _VarAmount);

                // Height and derivatives (screen-space ddx/ddy)
                float  h  = SAMPLE_TEXTURE2D(_BlueTex, sampler_BlueTex, uv).g; //use the texture’s green channel as a height field
                float  hx = ddx(h);
                float  hy = ddy(h);

                // Fake normal
                float3 n  = normalize(float3(-hx, -hy, NORMAL_Z));

                // Slope/curvature → crest mask (soft band)
                float slope  = saturate( sqrt(hx*hx + hy*hy) / 0.02 );
                float lap    = ddx(hx) + ddy(hy);
                float convex = saturate( (-lap) / 0.02 ); //approximate curvature
                float crestSlope = smoothstep(_SlopeThr - _BandSoft, _SlopeThr + _BandSoft, slope);
                float crestCurve = smoothstep(_CurveThr - _BandSoft, _CurveThr + _BandSoft, convex);
                float crestMask  = crestSlope * crestCurve;

                // Simple Blinn-Phong (view-up)
                float3 L = float3(0,0,1);
                float3 V = float3(0,0,1);
                float3 H = normalize(L+V);
                float ndotl = saturate(dot(n, L));
                float ndoth = saturate(dot(n, H));
                float spec  = pow(ndoth, SPEC_POWER) * _SpecStrength * ndotl * crestMask; //Tight highlight, scaled by light facing, and masked to crests

                baseRGB += spec * _SunColor.rgb; //add warm sunlight color to the base where crests are

                // Tone & tint
                float3 colLit = tone(baseRGB, _Contrast, _Brightness) * tint; //Adjust contrast/brightness and apply the tint color

                // Depth absorption
                float a0 = _AbsorbStartEnd.x, a1 = _AbsorbStartEnd.y;
                float depthT = saturate( (baseUV.y - a0) / max(1e-3, (a1 - a0)) ); //Maps UV.y from [a0..a1] to [0..1]
                colLit = lerp(colLit, colLit * _AbsorbColor.rgb, depthT * _AbsorbStrength);
                    //The farther/deeper (bigger depthT), the more the base color is pushed toward the absorb color (deep blue). 
                    //Highlights remain brighter on crests, so troughs show as darker blue lines.

                float3 col = colLit;
                col = max(col, _ShadowLift);
                col += _HighlightBoost * spec;

                return float4(saturate(col), 1);
            }
            ENDHLSL
        }
    }
}

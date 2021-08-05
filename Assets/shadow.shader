// Upgrade NOTE: replaced 'unity_World2Shadow' with 'unity_WorldToShadow'

Shader "Unlit/shadow"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
			#define SHADOWS_NATIVE

            #include "UnityCG.cginc"
			#include "AutoLight.cginc"
			
			//UNITY_DECLARE_SHADOWMAP(m_ShadowmapCopy);
			uniform sampler2D m_ShadowmapCopy;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
				//float4 _ShadowCoord: TEXCOORD2;
				float3 _worldpos : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

			//-----------------------------------------------------------------------------------------
			// GetCascadeWeights_SplitSpheres
			//-----------------------------------------------------------------------------------------
			inline fixed4 GetCascadeWeights_SplitSpheres(float3 wpos)
			{
				float3 fromCenter0 = wpos.xyz - unity_ShadowSplitSpheres[0].xyz;
				float3 fromCenter1 = wpos.xyz - unity_ShadowSplitSpheres[1].xyz;
				float3 fromCenter2 = wpos.xyz - unity_ShadowSplitSpheres[2].xyz;
				float3 fromCenter3 = wpos.xyz - unity_ShadowSplitSpheres[3].xyz;
				float4 distances2 = float4(dot(fromCenter0, fromCenter0), dot(fromCenter1, fromCenter1), dot(fromCenter2, fromCenter2), dot(fromCenter3, fromCenter3));

				fixed4 weights = float4(distances2 < unity_ShadowSplitSqRadii);
				weights.yzw = saturate(weights.yzw - weights.xyz);
				return weights;
			}

			//-----------------------------------------------------------------------------------------
			// GetCascadeShadowCoord
			//-----------------------------------------------------------------------------------------
			inline float4 GetCascadeShadowCoord(float4 wpos, fixed4 cascadeWeights)
			{
				float3 sc0 = mul(unity_WorldToShadow[0], wpos).xyz;
				float3 sc1 = mul(unity_WorldToShadow[1], wpos).xyz;
				float3 sc2 = mul(unity_WorldToShadow[2], wpos).xyz;
				float3 sc3 = mul(unity_WorldToShadow[3], wpos).xyz;

				float4 shadowMapCoordinate = float4(sc0 * cascadeWeights[0] + sc1 * cascadeWeights[1] + sc2 * cascadeWeights[2] + sc3 * cascadeWeights[3], 1);
#if defined(UNITY_REVERSED_Z)
				float  noCascadeWeights = 1 - dot(cascadeWeights, float4(1, 1, 1, 1));
				shadowMapCoordinate.z += noCascadeWeights;
#endif
				return shadowMapCoordinate;
			}

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
				o._worldpos = mul(unity_ObjectToWorld, v.vertex);
				//o._ShadowCoord = ComputeScreenPos(o.vertex); //mul(unity_WorldToShadow[0], o._worldpos);
				//o._ShadowCoord =  mul(unity_WorldToShadow[0], o._worldpos);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);

				float4 cascadeWeights = GetCascadeWeights_SplitSpheres(i._worldpos);
				bool inside = dot(cascadeWeights, float4(1, 1, 1, 1)) < 4;
				float4 samplePos = GetCascadeShadowCoord(float4(i._worldpos, 1), cascadeWeights);

				//float atten = inside ? UNITY_SAMPLE_SHADOW( m_ShadowmapCopy, samplePos.xyz) : 1.0f;
				float atten = inside ? tex2D(m_ShadowmapCopy, samplePos.xyz) : 1.0f;
				atten = (atten > samplePos.z)? 1 : 0;



				col = atten;
				col.w = 1;
				return col;
                // apply fog
                //UNITY_APPLY_FOG(i.fogCoord, col);
                //return col;
            }
            ENDCG
        }
    }
}

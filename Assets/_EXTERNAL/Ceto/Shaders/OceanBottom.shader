﻿
Shader "Ceto/OceanBottom" 
{
	SubShader 
	{
		Tags { "OceanMask"="Ceto_Ocean_Bottom" "RenderType"="Opaque" "Queue"="Background"}
		Pass 
		{
			
			zwrite off
			Fog { Mode Off }
			colorMask 0

			CGPROGRAM
			#include "UnityCG.cginc"
			#pragma target 2.0
			#pragma vertex vert
			#pragma fragment frag

			struct v2f 
			{
				float4  pos : SV_POSITION;
			};

			v2f vert(appdata_base v)
			{
				v2f o;
				
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				return o;
		 	} 
			
			float4 frag(v2f IN) : SV_Target
			{
			    return float4(0,0,0,1);
			}	
			
			ENDCG
		}
	}
}

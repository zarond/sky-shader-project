// в этом скрипте в шейдер передается положение куба

using System.Collections;
using System.Collections.Generic;
using UnityEngine;

//[ExecuteInEditMode]

public class CubeTransformsToShader : MonoBehaviour {
	Renderer rend;

	// Use this for initialization
	void Start () {
		rend = GetComponent<Renderer> ();
	}
	
	// Update is called once per frame
	void Update () {
		rend.sharedMaterial.SetVector("origin",(Vector4)(transform.position));
		//rend.sharedMaterial.SetMatrix ("World2Object",transform.worldToLocalMatrix); //оказалось не нужно
		rend.sharedMaterial.SetVector ("size", transform.localScale);
	}
}

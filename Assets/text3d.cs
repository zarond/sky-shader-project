// unity не позволяет напрямую импортировать 3D текстуру, только создавать из скрипта.
// этот скрипт создает 3d текстуру из 2d на старте программы.

using System.Collections;
using System.Collections.Generic;
using UnityEngine;

//[ExecuteInEditMode]

public class text3d : MonoBehaviour
{

	public Texture2D src;
	public int number;
	public int size1;

    public bool ClearFaces; // ������� ��������� ������� ���� �����������;
    public bool Clamp;
    Texture3D texture;
	//public Material material;
	public Material material;

    void Start ()
    { 
		//rend = GetComponent<Renderer> ();
        texture = CreateTexture3D (size1, src.width, number);
        if (Clamp) texture.wrapMode = TextureWrapMode.Clamp; else texture.wrapMode = TextureWrapMode.Repeat;
        material.SetTexture ("_3DTex",texture);
		//rend.material.SetVector("origin",(Vector4)(transform.position));
    }

	Texture3D CreateTexture3D (int size,int srcsize, int n)
    {
        Color[] colorArray = new Color[size * size * size];
		//byte[] colorArray = new byte[size * size * size]; //экономлю на описании плотности
        //texture = new Texture3D (size, size, size, TextureFormat.RGBA32, true);
		texture = new Texture3D (size, size, size, TextureFormat.RHalf, true); //экономлю на описании плотности

		for (int z = 0; z < size; ++z) {
			//int s = Mathf.FloorToInt(((float)z/size) * n * n);
			int s = (z* n * n) /size;
			float x0 = (float)((n * n - s)%n)/n;
			float y0 = (float)((s - 1)/n)/n;
			//Debug.Log("Z: "+z+" s: "+ s + " x0: " + x0 + " y0: " + y0);

			for (int x = 0; x < size; ++x) {
            	for (int y = 0; y < size; ++y) { 
					//float p = (float)z*srcsize/(n*size);
					//int p1 = Mathf.FloorToInt(p); int p2 = Mathf.CeilToInt(p); 
					//Color c1 = src.GetPixelBilinear((float)x/(n*size)  + (p1%(srcsize/n)) , (float)y/(n*size) + (p1 / (srcsize/n))) ;

					//Color c = src.GetPixelBilinear((float)x/(n*size)  + x0 , (float)y/(n*size) + y0) ;
					Color c = src.GetPixelBilinear((float)x/(n*size)  + x0 , (float)y/(n*size) + y0) ;
					colorArray[x + (y * size) + (z * size * size)] = c;
                }
            }
        }


        if (ClearFaces)
        {
            for (int x = 0; x < size; ++x)
                for (int y = 0; y < size; ++y)
                {
                    colorArray[x + (y * size)] = (Color.clear);
                }


            for (int x = 0; x < size; ++x)
                for (int y = 0; y < size; ++y)
                {
                    colorArray[x + (y * size) + ((size - 1) * size * size)] = (Color.clear);
                }


            for (int z = 0; z < 1; ++z)
                for (int y = 0; y < size; ++y)
                {
                    colorArray[0 + (y * size) + (z * size * size)] = (Color.clear);
                }


            for (int z = 0; z < 1; ++z)
                for (int y = 0; y < size; ++y)
                {
                    colorArray[(size - 1) + (y * size) + (z * size * size)] = (Color.clear);
                }


            for (int x = 0; x < size; ++x)
                for (int z = 0; z < 1; ++z)
                {
                    colorArray[x + 0 + (z * size * size)] = (Color.clear);
                }


            for (int x = 0; x < size; ++x)
                for (int z = 0; z < 1; ++z)
                {
                    colorArray[x + ((size - 1) * size) + (z * size * size)] = (Color.clear);
                }
        }
		texture.SetPixels (colorArray);
        texture.Apply ();
        return texture;
    }
        
}
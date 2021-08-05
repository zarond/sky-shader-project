using System.Collections;
using System.Collections.Generic;
using UnityEngine.Rendering;
using UnityEngine;

[RequireComponent(typeof(Camera))]
public class rmrchfog : MonoBehaviour
{

    public Light m_Light;
    RenderTexture m_ShadowmapCopy;
    public Material mat;
    private Camera camera;

    // Start is called before the first frame update
    void Start()
    {
        camera = GetComponent<Camera>();


        RenderTargetIdentifier shadowmap = BuiltinRenderTextureType.CurrentActive;
        m_ShadowmapCopy = new RenderTexture(2048, 1024, 0);
        //m_ShadowmapCopy = new RenderTexture(1024, 1024, 16, RenderTextureFormat.Shadowmap);
        CommandBuffer cb = new CommandBuffer();

        // Change shadow sampling mode for m_Light's shadowmap.
        cb.SetShadowSamplingMode(shadowmap, ShadowSamplingMode.RawDepth);
        //cb.SetShadowSamplingMode(shadowmap, ShadowSamplingMode.CompareDepths);

        // The shadowmap values can now be sampled normally - copy it to a different render texture.
        cb.Blit(shadowmap, new RenderTargetIdentifier(m_ShadowmapCopy));

        // Execute after the shadowmap has been filled.
        m_Light.AddCommandBuffer(LightEvent.AfterShadowMap, cb);

        // Sampling mode is restored automatically after this command buffer completes, so shadows will render normally.
        mat.SetTexture("m_ShadowmapCopy", m_ShadowmapCopy);
    }

    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        var p = GL.GetGPUProjectionMatrix(GetComponent<Camera>().projectionMatrix, false);// Unity flips its 'Y' vector depending on if its in VR, Editor view or game view etc... (facepalm)
        p[2, 3] = p[3, 2] = 0.0f;
        p[3, 3] = 1.0f;
        var clipToWorld = Matrix4x4.Inverse(p * GetComponent<Camera>().worldToCameraMatrix) * Matrix4x4.TRS(new Vector3(0, 0, -p[2, 2]), Quaternion.identity, Vector3.one);
        mat.SetMatrix("clipToWorld", clipToWorld);
        Graphics.Blit(src, dest, mat);
    }

}

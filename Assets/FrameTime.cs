using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class FrameTime : MonoBehaviour
{
    public Text fpsLabel;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        fpsLabel.text = Time.deltaTime.ToString();
    }
}

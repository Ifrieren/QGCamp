using System.Collections;
using System.Collections.Generic;
using UnityEngine;
[ExecuteInEditMode]
public class SetMaterialsFaceVector : MonoBehaviour
{
    public Transform Head;
    public Transform HeadForward;
    public Transform HeadRight;
    public Transform HeadUp;
    public Material FaceMaterial;


    void Update()
    {
        Vector3 headForward = Vector3.Normalize(HeadForward.position - Head.position);
        Vector3 headRight = Vector3.Normalize(HeadRight.position - Head.position);
        Vector3 headUp = Vector3.Normalize(HeadUp.position - Head.position);

        FaceMaterial.SetVector("_HeadForward", headForward);
        FaceMaterial.SetVector("_HeadUp", headUp);
        FaceMaterial.SetVector("_HeadRight", headRight);
    }
}

using System;
using System.IO;
using UnityEngine;

namespace VoronoiTexture
{
    /// <summary>
    /// Bakes a procedural Voronoi material into a render texture each frame.
    /// </summary>
    [ExecuteAlways]
    public class VoronoiBaker : MonoBehaviour
    {
        /// <summary>
        /// Material containing the Voronoi shader.
        /// </summary>
        public Material material;

        /// <summary>
        /// Resolution of the baked texture (16 to 4096).
        /// </summary>
        [Range(16, 4096)]
        public int resolution = 512;

        /// <summary>
        /// Indicates whether the texture should bake every frame.
        /// </summary>
        public bool liveUpdate = true;

        /// <summary>
        /// Optional renderer to apply the baked texture to.
        /// </summary>
        public Renderer targetRenderer;

        /// <summary>
        /// Name of the property on the target renderer's material to assign the texture to.
        /// </summary>
        public string targetTextureProperty = "_BaseMap";

        /// <summary>
        /// The currently baked render texture.
        /// </summary>
        public RenderTexture Output { get; private set; }

        private MaterialPropertyBlock _propertyBlock;

        private void Update()
        {
            if (liveUpdate)
            {
                Bake();
            }
        }

        /// <summary>
        /// Bakes the material into the Output render texture and optionally applies it to the target renderer.
        /// </summary>
        public void Bake()
        {
            if (material == null)
            {
                return;
            }

            EnsureRT();
            Graphics.Blit(null, Output, material, 0);

            if (targetRenderer != null && targetRenderer.sharedMaterial != null)
            {
                if (targetRenderer.sharedMaterial.HasProperty(targetTextureProperty))
                {
                    // MaterialPropertyBlock keeps the material asset untouched (no dirty .mat in edit mode).
                    if (_propertyBlock == null) _propertyBlock = new MaterialPropertyBlock();
                    targetRenderer.GetPropertyBlock(_propertyBlock);
                    _propertyBlock.SetTexture(targetTextureProperty, Output);
                    targetRenderer.SetPropertyBlock(_propertyBlock);
                }
            }
        }

        private void EnsureRT()
        {
            resolution = Mathf.Clamp(resolution, 16, 4096);

            if (Output != null && (Output.width != resolution || Output.height != resolution))
            {
                ReleaseRT();
            }

            if (Output == null)
            {
                Output = new RenderTexture(resolution, resolution, 0, RenderTextureFormat.ARGB32)
                {
                    wrapMode = TextureWrapMode.Repeat,
                    filterMode = FilterMode.Bilinear,
                    name = "VoronoiRT"
                };
            }
        }

        private void ReleaseRT()
        {
            if (Output != null)
            {
                Output.Release();
                
                if (Application.isPlaying)
                {
                    Destroy(Output);
                }
                else
                {
                    DestroyImmediate(Output);
                }
                
                Output = null;
            }
        }

        private void OnDisable()
        {
            ReleaseRT();
        }

        private void OnDestroy()
        {
            ReleaseRT();
        }

        /// <summary>
        /// Bakes and saves the current output as a PNG image to disk.
        /// </summary>
        [ContextMenu("Save PNG")]
        public void SavePng()
        {
            Bake();

            if (Output == null)
            {
                return;
            }

            RenderTexture previousActive = RenderTexture.active;
            RenderTexture.active = Output;

            Texture2D tempTexture = new Texture2D(Output.width, Output.height, TextureFormat.RGBA32, false);
            tempTexture.ReadPixels(new Rect(0, 0, Output.width, Output.height), 0, 0);
            tempTexture.Apply();

            RenderTexture.active = previousActive;

            byte[] pngData = tempTexture.EncodeToPNG();

            if (Application.isPlaying)
            {
                Destroy(tempTexture);
            }
            else
            {
                DestroyImmediate(tempTexture);
            }

            string fileName = $"Voronoi_{DateTime.Now:yyyyMMdd_HHmmss}.png";
            string filePath;

#if UNITY_EDITOR
            string directory = "Assets/VoronoiTexture/Baked";
            Directory.CreateDirectory(directory);
            filePath = Path.Combine(directory, fileName);
            File.WriteAllBytes(filePath, pngData);
            UnityEditor.AssetDatabase.Refresh();
#else
            filePath = Path.Combine(Application.persistentDataPath, fileName);
            File.WriteAllBytes(filePath, pngData);
#endif

            Debug.Log($"Voronoi texture saved to: {filePath}");
        }
    }
}

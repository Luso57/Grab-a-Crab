Sandcastle - corrected textured exports

Sandcastle.fbx now includes an embedded PNG color texture and exactly one UV layer. Keep Sandcastle_Color.png alongside the FBX as an external fallback.
Sandcastle.glb also embeds the texture. The .blend has the image packed.
FBX was reimported into Blender and every exported UV sampled the expected original RGB. GLB was checked for the correct mesh count, embedded image, material texture reference, and UV coordinates. This is not a Roblox Studio verification.

To repair old uncolored imports without reimporting: select those models in Studio and run ../RepairImportedColors.luau in the Command Bar. It only recolors selected meshes with recognized original names.
For newly textured imports, FinishImport.luau preserves textures and uses white MeshPart tint; it still anchors and organizes the model.

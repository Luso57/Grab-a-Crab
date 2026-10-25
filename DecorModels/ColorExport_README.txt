COLOR-CORRECTED ROBLOX EXPORTS

Reimport SkullTankDecoration.fbx, TreasureChestDecoration.fbx and MiniBeachUmbrella.fbx using Studio's 3D Importer. Each FBX embeds its own 128x128 color palette. Keep the matching *_Colors.png beside each FBX as an external fallback. If a texture is not automatically assigned, upload the matching PNG and use it as the mesh TextureID or SurfaceAppearance ColorMap.

The original Blender files and materials are unchanged. Geometry, object names, transforms, lid pivot and triangle counts are preserved. Only the affected FBX files were replaced; Shipwreck files were not changed.

Cause: the old three exports had Blender material colors but no embedded textures. The working Shipwreck uses a UV-mapped color palette. Corrected files now follow that same approach with one textured material per mesh.

Validated by binary inspection and Blender reimport, including exact recovered texture pixels. Roblox Studio import has not been tested in this session.

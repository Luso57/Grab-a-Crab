# Crab models — batch 2

This folder contains **18 new FBX models**, each with its **1024 x 1024 PNG color texture embedded inside the FBX**. The matching `CrabName_Color.png` is also included beside it.

Open `CrabCollection.png` to see all 18 skins. Individual renders are in `Previews`.

## Import into Roblox Studio

1. Keep the FBX and matching PNG files together in this folder.
2. Click **Home > Import** or press **Ctrl+M**, then select a crab's `.fbx` file.
3. Check the import preview. Its colors and surface pattern should already appear.
4. Leave **Merge Meshes** disabled to preserve the separate body, arms, claws, and legs.
5. Click **Import** when you are ready to add the crab to your game.

The textures are already embedded, so you normally do not need to upload the PNGs separately. If Studio fails to attach a texture, upload the matching `_Color.png` and assign its asset ID to every MeshPart's `TextureID`, or to its existing SurfaceAppearance's `ColorMap`. All parts of a given crab use the same atlas.

## Included skins

Sushi, Pizza, Pineapple, Strawberry, Popcorn, Coffee, Ramen, Origami, Patchwork, Porcelain, Sunflower, Coral Reef, Race Car, Firefighter, Detective, Pharaoh, Viking, and Music.

Filenames use compact names such as `CoralReefCrab.fbx` and `RaceCarCrab.fbx`.

Each crab keeps the original proportions and 28 named mesh parts. Accessories are joined to the body or claw they belong to. Body and limb names follow the existing `CrabName_Body`, `CrabName_Claw_L`, and `CrabName_Leg_L_01` convention. The exports contain no animation tracks or scripts.

## Verification

- All 18 exported FBXs were reopened in a fresh Blender process.
- The embedded PNG bytes match the supplied PNG files exactly.
- Every mesh recovered its image texture, UV map, and single material.
- All models passed checks for collapsed UV triangles, open mesh edges, grounded position, and export scale.
- Each complete crab has between 4,648 and 6,660 triangles.
- Sushi Crab was checked in Roblox Studio's **Import Preview**. Its salmon stripes, seaweed band, and colors appeared correctly. See `Previews/RobloxImportPreview.png`.
- The preview was closed without importing or uploading Sushi Crab, and its test queue entry was removed.
- All 28 original parts still match the saved base backup in geometry, transforms, UVs, and material colors.

`manifest.json` lists the models. `validation.json` contains the per-model checks.

The editable source is saved at `../artifacts/crab-variants-batch2/CrabVariants2.blend`, with the new models in the **Crab Variants 2** scene and their texture images packed into the file.

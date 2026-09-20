![SO FLUFFY](screenshots/title.png)

# SO FLUFFY!

High-quality, endlessly configurable fur for Godot 4 with bouncy physics.

# What is it?

SO FLUFFY is a shell fur rendering system for Godot 4. Shell rendering involves rendering multiple copies of an object's geometry, scaling each one up a little more, thus creating a series or "shells" of increasing size surrounding the object.

A shader is then used to render cross-sections of fur strands on each shell.

![LOD demo](screenshots/bee.png)

# Features

- Performance
    - Material-based shell generation, no geometry is duplicated. SO FLUFFY uses a cascade of next_pass materials for subsequent shells and performs all geometry operations in its vertex shader
    - dynamic LODs through disabling shells based on camera distance
- Control over strand growth:
    - fur density (strands per area)
    - scruffiness (length distribution of strands)
    - heightmap texture for precise control over where strands can grow
    - turbulence and jitter - overlay noise for displacing strands for a more organic look, or to model things like cowlicks
    - thickness profile - control the thickness of strands over their length to produce finer or thicker hair, or other organic shapes like moss or fungus
    - Fur can grow along surface normals, in a fixed direction relative to the object, or in a fixed direction in world space, or any combination of those
- Control over appearance:
    - color gradient applied along the length of each strand, usefule for simulating self-shadowing or other effects (see demos)
    - albedo color - solid color or texture
    - emission - solid color or texture
- Physics
    - linear spring physics for satisfying bounciness on linear movement
    - rotational spring physics for satisfying swishiness on rotation
    - rotational physics effects can be scaled independently

# Quick start

1. install the plugin by placing the so_fluffy folder inside the "addons" folder in your project
2. open Godot "Project Settings->Plugins" and enable the SoFluffy plugin
3. Add some geometry to your scene - any subclass of GeometryInstance3D can be used to grow fur.
4. Add a Fur node as a child of your geometry and tweak parameters to your liking.

# Caveats

## Performance

Shell rendering is not exactly cheap. The major driver of rendering cost is the number of shells - the cost of rendering is O(N). Some features incur additional performance cost - any time a texture is used (height map, turbulence, albedo, emission, thickness curve, height gradient), more texture samples are required, which places extra load on the GPU.

### Performance tips:

- keep the number of shells as low as possible
- minimse use of texture lookups (see above)
- turn on dynamic LOD
- keep your geometry simple - each shell has to render each triangle in your original geometry. Use simpler representations of your geometry for fur - the inherent noisiness of the fur can often mask the loss of geometric detail

## Noise and other artefacts

Because strands are rendered as a series of (infinitely) thin shells, viewing fur side-on causes a lot of visual noise. Two common approaches to solve this issues are to render textured "fins" perpendicular to the camera, or to perform some sort of post-process blurring in screen space.

Fin textures generally need to be hand-crafted to match the look of the fur being rendered; this addon does not intend to provide a fin rendering implementation.

SO FLUFFY also does not currently provide any post-processing to reduce noise, this may change in the future.

# LODs

SO FLUFFY comes with a simple dynamic LOD system. Since performance is mainly dependent on the number of shells being rendered, reducing the number of shells for far-away objets can help control the performance load.

LODs are generated dynamically by dropping shells based on distance. This is done per-object, so if you're rendering terrain, it is advisable to break up the terrain into a number of separate, sufficiently small tiles to take advantage of this feature.

![LOD demo](screenshots/LOD.png)

# Usage

## Setup

SO FLUFFY can be applied to any geometry in Godot that inherits from GeometryNode3D. Simply add a "Fur" node as a child of the geometry you want to grow fur on.

## Targeting

By default, SO FLUFFY uses the Geometry Node's Material Overlay to render fur.

If attached to a MeshInstance3D, you can optionally configure the fur system to render on one or more surfaces instead. To do so, configure the surface indices in the "Targeting" section.

# Demos

SO FLUFFY comes with a number of demo scenes that illustrate some of the system's features.

- basic_hair: basic usage - simple hair, slight turbulence and basic physics setup
- lod_test: demonstrates the effect of the dynamic LOD by showing LOD and FPS stats for an object moving away from the camera
- hedgehog: uses the following features to render something approximating the spikes of a hedgehog:
    - heightmap texture (to control where the spikes are grown)
    - rotational physics scaling to mostly disable rotational physics
    - height gradient for stripy spikes
    - thickness curve for the spike shape
- enoki: uses the thickness curve to render a large field of mushroom-shaped strands
- bee: a fuzzy animated bee, demonstrating use of a skinned mesh, surface targeting, and Albedo texture. Bee model courtesy of https://github.com/gdquest-demos/godot-4-3D-Characters

![LOD demo](screenshots/enoki.png)

# Fur Parameters

## General

### Preview in Editor

For configuring fur parameters, it is very handy to be able to preview the fur in the editor. However, since fur rendering comes at a performance cost, it is often advisable to turn off the editor preview. Enabling this feature will clear and re-generate all shells from scratch.

This setting does not affect runtime behaviour - fur rendering is always enabled at runtime.

## Targeting

### Target Surfaces

Indices of surfaces to apply fur to. If empty, fur is applied to the entire mesh as a single overlay Material. Otherwise, fur is applied only to the specified surfaces.

## Performance and LODs

### Number of shells

The maximum number of shells used to render the fur. More shells are more expensive to render. For fur that is intended to be seen close up, 128 or even 256 shells may be desirable - but balance this with performance concerns. For far-away fur, or things like distant vegetation, values as low as 16 shells may be entirely sufficient.

Note that if LOD is enabled, the LOD settings affect how many shells are actually rendered; this is the upper limit.

### LOD enabled

Turn dynamic LOD on or off. If LOD is off, the fur is always rendered with the maximum number of shells.

LOD switching is based on bounding-box distance to the camera. You may want to set the distances based on screen resolution and camera FOV for your specific use case.

Since dropping shells for lower LODs ultimately results in fewer fur pixels being rendered, fur appears "thinner" at less detailed LOD levels. The LOD system compensates for this by adjusting the thickness of each strand to maintain a consistent visual weight over the entire LOD range.

### LOD Min Distance

Minimum distance from the camera at which lower-detail LODs are used. Any objects close than this distance will be rendered with highest quality.

### LOD Max Distance

Distance from the camera at which the lowest level LOD is used. Any objects further from the camera will be rendered at the lowest quality.

### LOD Minimum Shells

The number of shells to use for the lowest-quality LOD. Default and lower bound is 8, which should be a good value in most cases.

## Shape and Growth

### Length

Strand length. This determines how much the shells are scaled up. Longer strands require more shells to render - balance this with performance concerns.

### Density

Scaling of the fur density - strands per area. Higher numbers make the fur more dense. So FLUFFY uses UV0 coordinates for seeding noise, so you need to make sure your model has reasonable evenly-spaced UVs.

### Scruffiness

Variation of the height distribution of strands. Higher values for a more scruffy look.

### Heightmap Texture

Fur heightmap texture. Values scale hair length by [1..0[. Black pixels are not rendered, so the underlying skin material will be visible.

### Strand Thickness

#### Thickness Curve

Thickness profile of a single strand. Note that the values are inverted (1 it thin, 0 is thick) so that the curve presets can be used.

This curve can be used to achieve some interesting effects - see the included Enoki demo scene.

#### Thickness Scale

Uniformly scales up th thickness of all strands. Thicker strands give the visual impression of denser fur.

### Turbulence and Jitter

#### Turbulence Texture

Noise texture to overlay turbulence on the fur. Uses r and g channels to calculate a displacement vector, so is best provided as a normal map. Turbulence scales with density.

#### Turbulence Strength

Strength of the turbulence effect. Higher numbers apply more turbulence.

#### Jitter Texture

Noise texture to overlay UV-space turbulence on the fur. Uses r and g channels to calculate a displacement vector, so is best provided as a normal map. Jitter does not scale with density.

#### Jitter Strength

Strength of the Jitter noise effect.

### Growth Direction

#### Normal Strength

Blends the fur growth direction between the surface normal and the static directions below. A value of 1 means fur grows only in the direction of normals, a value of 0 means it grows only in a static direction.

#### Static Direction Local

Static direction of fur growth in object space. This is useful for fur that grows in a specific direction but moves with the object, such as a stiff mane or a mohawk.

#### Static Direction World

Static direction of fur growth in world space. This is useful for fur that grows in a specific direction in world coordinates, such as grass, which always grows upwards.


## Appearance

### Height Gradient

Albedo color is multiplied by this gradient, sampled by relative height. The default gradient simulates ambient occlusion.

If no gradient is provided, a simple (cheaper) power function is used to achieve the effect.

### Scale Height Gradient

Should the height gradient be scaled with the length of individual strands? If true, each strand will use the full gradient, otherwise shorter strands only use a partial gradient.

### Render Skin

If enabled, all pixels on shell 0 are rendered. Otherwise, non-strand pixels are transparent. This is useful if you do not want to incur the overhead of a dedicated skin material. Defaults to false.

### Albedo

#### Albedo Color

Plain hair color. This color is multiplied by the height gradient, and the albedo texture, if provided. Think of it as the base "tint" of the fur.

#### Albedo Texture

Texture defining hair color. Albedo color is [i]multiplied[\i] by the texture color.

### Emission

#### Use Emission

Enable/disable rendering of emission component.

#### Emission Color

Uniform emission color.

#### Emission Energy Multiplier

Emission energy multiplier. Higher numbers make the emission brighter.

#### Emission Texture

Texture defining emission color. Emission color is [i]added[i] to the texture color.

## Physics

Physics offsets are passed to the shader as per-instance uniforms (`physics_pos_offset`, `physics_rot_offset`) on the geometry node. If you attach several Fur nodes to the same geometry, they share one physics state - the node that updates last wins, so give them identical physics settings.

### Physics Enabled

Disable physics processing altogether. Physics simulation is very cheap, but should be disabled if the fur will not be subject to any movement.

### Physics Preview

Simulate physics in the editor. Physics simulation is very cheap, but can be distracting while editing.

### Rotational Physics Scale

Adjust the magnitude of rotational physics effects, relative to those of the linear physics. This is useful to model more rigid fur - see the Hedgehog demo for an example where rotational physics are scaled down.

### Gravity

Constant gravity affecting the fur.

### Spring Constant

Defines the spring constant. Higher values mean a stronger spring.

### Mass

Strand mass - higher numbers make the hair more resistant to movement.

### Damping

Spring damping - higher values make the fur move more slowly and suppress oscillations.

### Stretch

Values greater than 1 allow strands to stretch beyond Length. This gives the visual impression of more elastic, flowy fur.

### Stiffness

Controls how stiff the strands are over their length - higher numbers make the strands more bendy, lower numbers give a more bristly look.
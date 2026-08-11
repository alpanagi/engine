struct Instance {
    position: vec4<f32>,
}

struct Camera {
    view_projection: mat4x4<f32>,
}

@group(0) @binding(0) var<storage, read> instances: array<Instance>;
@group(1) @binding(0) var<uniform> camera: Camera;

@vertex
fn vertex(
    @builtin(instance_index) instance_index: u32,
    @location(0) position: vec3<f32>,
) -> @builtin(position) vec4<f32> {
    let instance = instances[instance_index];
    return camera.view_projection * vec4<f32>(position + instance.position.xyz, 1.0);
}

@fragment
fn fragment() -> @location(0) vec4<f32> {
    return vec4<f32>(1.0, 1.0, 1.0, 1.0);
}

struct VertexOutput {
    @builtin(position) position: vec4f,
}

@vertex
fn vertex() -> VertexOutput {
    var out: VertexOutput;
    out.position = vec4f(0.0, 0.0, 0.0, 1.0);
    return out;
}

@fragment
fn fragment() -> @location(0) vec4f {
    return vec4f(0.0, 0.0, 0.0, 0.0);
}

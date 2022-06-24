struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) color: vec3<f32>,
};

@vertex
fn main_vs(
    @location(0) cell: f32,
    @location(1) position: vec2<f32>,
    @builtin(instance_index) inst_index: u32
) -> VertexOutput {
    var out: VertexOutput;
    let n_rows = 1000u;
    let d = 2.0 / f32(n_rows);

    let x = f32(inst_index % n_rows);
    let xpos = d * x - 1.0;

    let y = f32(inst_index / n_rows);
    let ypos = d * y - 1.0;

    out.position = vec4<f32>(position.x + xpos, position.y + ypos, 0.0, 1.0);
    if cell > 0.5 {
        out.color = vec3<f32>(1.0, 1.0, 1.0);
    } else {
        out.color = vec3<f32>(0.0, 0.0, 0.0);
    };
    return out;
}

@fragment
fn main_fs(in: VertexOutput) -> @location(0) vec4<f32> {
    return vec4<f32>(in.color, 1.0);
}

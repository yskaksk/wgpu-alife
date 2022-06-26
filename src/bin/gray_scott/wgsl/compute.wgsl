struct UV {
    u : f32,
    v : f32
};

@group(0) @binding(0)
var<storage, read> cellsSrc : array<UV>;

@group(0) @binding(1)
var<storage, read_write> cellsDst : array<UV>;

fn cell_to_index(x: i32, y: i32, n_rows: u32) -> u32 {
    let n_rows = i32(n_rows);
    // x, yは負になることもあるのでわざわざ剰余を計算している
    return u32((x % n_rows) + n_rows * (y % n_rows));
}

@compute
@workgroup_size(256)
fn main(@builtin(global_invocation_id) global_invocation_id: vec3<u32>) {
    let length = arrayLength(&cellsSrc);
    let index = global_invocation_id.x;
    if (index >= length) {
        return;
    }
    let n_rows = 500u;

    let dx = 0.01;
    let dt = 1.0;
    let Du = 0.00002;
    let Dv = 0.00001;
    // スポット
    //let f = 0.022;
    //let k = 0.058;
    // 非結晶
    //let f = 0.04;
    //let k = 0.06;
    let f = 0.025;
    let k = 0.06;

    let x = i32(index % n_rows);
    let y = i32(index / n_rows);

    let cell = cellsSrc[index];

    var l_u = 0.0;
    if (x - 1 >= 0) {
        l_u += cellsSrc[cell_to_index(x - 1, y, n_rows)].u;
    }
    if (y - 1 >= 0) {
        l_u += cellsSrc[cell_to_index(x, y - 1, n_rows)].u;
    }
    if (x + 1 < i32(n_rows)) {
        l_u += cellsSrc[cell_to_index(x + 1, y, n_rows)].u;
    }
    if (y + 1 < i32(n_rows)) {
        l_u += cellsSrc[cell_to_index(x, y + 1, n_rows)].u;
    }
    l_u = (l_u - 4.0 * cell.u) / (dx * dx);
    var l_v = 0.0;
    if (x - 1 >= 0) {
        l_v += cellsSrc[cell_to_index(x - 1, y, n_rows)].v;
    }
    if (y - 1 >= 0) {
        l_v += cellsSrc[cell_to_index(x, y - 1, n_rows)].v;
    }
    if (x + 1 < i32(n_rows)) {
        l_v += cellsSrc[cell_to_index(x + 1, y, n_rows)].v;
    }
    if (y + 1 < i32(n_rows)) {
        l_v += cellsSrc[cell_to_index(x, y + 1, n_rows)].v;
    }
    l_v = (l_v - 4.0 * cell.v) / (dx * dx);

    let dudt = Du * l_u - cell.u * cell.v * cell.v + f * (1.0 - cell.u);
    let dvdt = Dv * l_v + cell.u * cell.v * cell.v - (f + k)*cell.v;

    let u = cell.u + dt * dudt;
    let v = cell.v + dt * dvdt;

    cellsDst[index] = UV(u, v);
}

@group(0) @binding(0)
var<storage, read> cellsSrc : array<f32>;

@group(0) @binding(1)
var<storage, read_write> cellsDst: array<f32>;

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
    let x = i32(index % n_rows);
    let y = i32(index / n_rows);

    let sum = cellsSrc[cell_to_index(x - 1, y - 1, n_rows)]
            + cellsSrc[cell_to_index(x - 1, y,     n_rows)]
            + cellsSrc[cell_to_index(x - 1, y + 1, n_rows)]
            + cellsSrc[cell_to_index(x,     y - 1, n_rows)]
            + cellsSrc[cell_to_index(x,     y + 1, n_rows)]
            + cellsSrc[cell_to_index(x + 1, y - 1, n_rows)]
            + cellsSrc[cell_to_index(x + 1, y,     n_rows)]
            + cellsSrc[cell_to_index(x + 1, y + 1, n_rows)];
    let sum = u32(sum);

    var val = 0.0;
    if (sum == 2u) {
        val = cellsSrc[index];
    }
    if (sum == 3u) {
        val = 1.0;
    }
    cellsDst[index] = val;
}

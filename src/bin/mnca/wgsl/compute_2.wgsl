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
@workgroup_size(64)
fn main(@builtin(global_invocation_id) global_invocation_id: vec3<u32>) {
    let length = arrayLength(&cellsSrc);
    let index = global_invocation_id.x;
    if (index >= length) {
        return;
    }
    let n_rows = 1000u;
    let x = i32(index % n_rows);
    let y = i32(index / n_rows);

    var sum: f32 = 0.0;
    for(var i: i32 = -5; i <= 5; i++) {
        for(var j: i32 = -5; j <= 5; j++) {
            if (i == 0 && j == 0) {
                continue
            }
            sum += cellsSrc[cell_to_index(x + i, y + j, n_rows)];
        }
    }
    var val = cellsSrc[index];
    if (sum < 33.0) {
        val = 0.0;
    }
    if (sum >= 34.0 && sum <= 45.0) {
        val = 1.0;
    }
    if (sum >= 58.0 && sum <= 121.0) {
        val = 0.0;
    }
    cellsDst[index] = val;
}


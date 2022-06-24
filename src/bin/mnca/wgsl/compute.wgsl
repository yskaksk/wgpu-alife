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

    var sum1: f32 = 0.0;
    var count: f32 = 0.0;
    for(var i: i32 = -7; i <= 7; i++) {
        for(var j: i32 = -7; j <= 7; j++) {
            let r = i * i + j * j;
            if (r < 55  && r > 22 ){
                sum1 += cellsSrc[cell_to_index(x + i, y + j, n_rows)];
                count += 1.0;
            }
        }
    }
    sum1 /= count;

    var sum2: f32 = 0.0;
    var count: f32 = 0.0;
    for(var i: i32 = -3; i <= 3; i++) {
        for(var j: i32 = -3; j <= 3; j++) {
            let r = i * i + j * j;
            if (r < 12) {
                sum2 += cellsSrc[cell_to_index(x + i, y + j, n_rows)];
                count += 1.0;
            }
        }
    }
    sum2 -= cellsSrc[index];
    sum2 /= count;

    var val = cellsSrc[index];
    if (sum1 >= 0.21 && sum1 <= 0.23) {
        val = 1.0;
    }
    if (sum1 >= 0.35 && sum1 <= 0.5) {
        val = 0.0;
    }
    if (sum1 >= 0.75 && sum1 <= 0.85) {
        val = 0.0;
    }
    if (sum2 >= 0.1 && sum2 <= 0.3) {
        val = 0.0;
    }
    if (sum2 >= 0.4 && sum2 <= 0.55) {
        val = 1.0;
    }
    if (sum1 >= 0.12 && sum1 <= 0.17) {
        val = 0.0;
    }
    cellsDst[index] = val;
}

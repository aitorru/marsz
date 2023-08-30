#[no_mangle]
pub extern "C" fn start(c: bool) -> bool {
    println!("Hello from Rust!");
    c
}

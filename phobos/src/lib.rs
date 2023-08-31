#[no_mangle]
pub extern "C" fn start(c: bool) -> bool {
    println!("Hello from Rust!");
    c
}

// #[no_mangle]
// pub extern "C" fn formatString<'a>(c: &'a [u8], args: &'a [u8]) -> &'a [u8] {
//     c
// }

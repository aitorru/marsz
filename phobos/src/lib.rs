use futures::stream::StreamExt;
use mongodb::{
    bson::{doc, oid::ObjectId},
    options::ClientOptions,
    Client,
};
use serde::{Deserialize, Serialize};
use std::ffi::{c_char, CStr};
use tokio;

#[no_mangle]
pub extern "C" fn start() {
    println!("\nHello from Rust!\n");
}

#[no_mangle]
pub extern "C" fn get_list_contents(u: *const c_char, p: *const c_char) -> *const c_char {
    let credentials: Credentials = Credentials {
        username: translate_pointer(u).unwrap(),
        password: translate_pointer(p).unwrap(),
    };

    let rs = connect_and_get_data_async(credentials);

    match rs {
        Ok(result) => {
            let json = serde_json::to_string(&result).unwrap();
            translate_string(json).unwrap()
        }
        Err(_) => translate_string("Error".to_string()).unwrap(),
    }
}
#[derive(Debug)]
struct Credentials {
    username: String,
    password: String,
}

// Define a type that models our data.
#[derive(Clone, Debug, Deserialize, Serialize)]
struct Link {
    #[serde(rename = "_id")]
    _id: ObjectId,
    name: String,
    link: String,
}

#[tokio::main]
async fn connect_and_get_data_async(credentials: Credentials) -> mongodb::error::Result<Vec<Link>> {
    println!("{:?}", credentials);
    // TODO: Credentials are fucked.
    let uri = "mongodb://root:example@localhost:27017/";
    let client_options = ClientOptions::parse(uri).await?;

    // Create a new client and connect to the server
    let client = Client::with_options(client_options)?;
    // Send a ping to confirm a successful connection

    // Get all documents from the database mars and the links folder
    let collection = client.database("mars").collection::<Link>("links");

    let filter = doc! {};

    let mut cursor = collection.find(filter, None).await?;

    let mut results: Vec<Link> = vec![];

    while let Some(link) = cursor.next().await {
        match link {
            Ok(document) => results.push(document.clone()),
            Err(err) => {
                // Handle errors
                println!("Error: {:?}", err);
            }
        }
    }

    Ok(results)
}

#[derive(Debug, Clone)]
struct PointerError;

fn translate_pointer(entry: *const c_char) -> Result<String, PointerError> {
    // Avoid clones and unwrap safely
    unsafe {
        if entry.is_null() {
            return Err(PointerError);
        }

        let cstr_slice = CStr::from_ptr(entry);
        cstr_slice
            .to_str()
            .map(|s| s.to_string())
            .map_err(|_| PointerError)
    }
}
#[allow(dead_code)]
fn translate_string(entry: String) -> Result<*mut c_char, PointerError> {
    std::ffi::CString::new(entry)
        .map(|s| s.into_raw())
        .map_err(|_| PointerError)
}

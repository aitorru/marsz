use futures::stream::StreamExt;
use mongodb::{
    bson::{doc, oid::ObjectId},
    options::ClientOptions,
    Client,
};
use serde::{Deserialize, Serialize};
use std::ffi::{c_char, CStr};
use tokio;
use urlencoding::decode;

#[no_mangle]
pub extern "C" fn start() {
    println!("\nHello from Rust!\n");
}

#[no_mangle]
pub extern "C" fn decode_url(u: *const c_char) -> *const c_char {
    let url: String = translate_pointer(u).unwrap();

    match decode(&url) {
        Ok(decoded_url) => translate_string(decoded_url.into_owned()).unwrap(),
        Err(_) => translate_string("Error".to_string()).unwrap(),
    }
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

#[no_mangle]
pub extern "C" fn upload_new_link(
    n: *const c_char,
    l: *const c_char,
    u: *const c_char,
    p: *const c_char,
) -> bool {
    let credentials: Credentials = Credentials {
        username: translate_pointer(u).unwrap(),
        password: translate_pointer(p).unwrap(),
    };

    let link = Link {
        _id: ObjectId::new(),
        name: translate_pointer(n).unwrap(),
        link: translate_pointer(l).unwrap(),
    };

    let rs = upload_new_link_async(credentials, link);

    match rs {
        Ok(_) => true,
        Err(_) => false,
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
    // TODO: Credentials are fucked.
    let uri = format!(
        "mongodb://{}:{}@localhost:27017/",
        credentials.username, credentials.password
    );
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

#[tokio::main]
async fn upload_new_link_async(credentials: Credentials, link: Link) -> mongodb::error::Result<()> {
    println!("Credentials: {:?}", credentials);
    println!("Link: {:?}", link);

    let uri = format!(
        "mongodb://{}:{}@localhost:27017/",
        credentials.username, credentials.password
    );
    let client_options = ClientOptions::parse(uri).await?;

    // Create a new client and connect to the server
    let client = Client::with_options(client_options)?;
    // Send a ping to confirm a successful connection

    // Get all documents from the database mars and the links folder
    let collection = client.database("mars").collection::<Link>("links");

    let _ = collection.insert_one(link, None).await?;

    Ok(())
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

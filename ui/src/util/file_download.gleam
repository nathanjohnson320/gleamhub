/// Save a file from an authenticated API URL (browser download dialog).
@external(javascript, "./file_download_ffi.js", "downloadAuthenticated")
fn download_authenticated(url: String, token: String, filename: String) -> Nil

pub fn download(url: String, token: String, filename: String) -> Nil {
  download_authenticated(url, token, filename)
}

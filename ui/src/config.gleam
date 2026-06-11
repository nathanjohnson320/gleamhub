import gleam/option.{type Option}

pub type Config {
  Config(api_url: String, token: Option(String))
}

pub fn with_token(config: Config, token: String) -> Config {
  Config(..config, token: option.Some(token))
}

use anyhow::Result;
use tracing_subscriber::filter::LevelFilter;

mod cli;
mod cli_commands;
mod data_types;

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing to see network events and output
    tracing_subscriber::fmt()
        .with_max_level(LevelFilter::INFO)
        .with_test_writer()
        .init();

    cli::run().await
}

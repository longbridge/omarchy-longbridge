use std::io;

use clap::{Parser, Subcommand};
use longbridge_market_pulse_helper::protocol::{write_event, ErrorEvent, Event};

#[derive(Debug, Parser)]
#[command(name = "longbridge-helper")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    Auth {
        #[command(subcommand)]
        command: AuthCommand,
    },
    Stream { symbols: Vec<String> },
    Search { query: String },
}

#[derive(Debug, Subcommand)]
enum AuthCommand {
    Status,
    Login,
    Logout,
}

fn main() -> anyhow::Result<()> {
    let _command = Cli::parse().command;
    write_event(
        &mut io::stdout().lock(),
        &Event::Error(ErrorEvent {
            code: "not_implemented".to_string(),
            message: "This helper command is not implemented yet.".to_string(),
        }),
    )
}

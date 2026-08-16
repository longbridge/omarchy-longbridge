use std::io;
use std::process::ExitCode;

use clap::{Parser, Subcommand};
use longbridge_market_pulse_helper::auth::{self, AuthState};
use longbridge_market_pulse_helper::context::SdkQuoteSource;
use longbridge_market_pulse_helper::protocol::{write_event, ErrorEvent, Event};
use longbridge_market_pulse_helper::stream;

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
    Stream {
        symbols: Vec<String>,
    },
    Search {
        query: String,
    },
}

#[derive(Debug, Subcommand)]
enum AuthCommand {
    Status,
    Login,
    Logout,
}

#[tokio::main]
async fn main() -> ExitCode {
    let command = Cli::parse().command;
    let mut output = io::stdout().lock();
    match command {
        Command::Auth {
            command: AuthCommand::Status,
        } => {
            let state = auth::status();
            let (state, message) = match state {
                AuthState::Authenticated => ("authenticated", "Connected to Longbridge."),
                AuthState::NotAuthenticated => {
                    ("not_authenticated", "Connect your Longbridge account.")
                }
                AuthState::TokenUnreadable => (
                    "token_unreadable",
                    "The shared Longbridge login cannot be decrypted on this machine.",
                ),
            };
            emit(
                &mut output,
                Event::Auth {
                    state: state.to_string(),
                    message: message.to_string(),
                },
                ExitCode::SUCCESS,
            )
        }
        Command::Stream { symbols } => {
            if stream::normalized_symbols(symbols.clone()).is_err() {
                return emit_error(
                    &mut output,
                    "invalid_symbol",
                    "Use symbols such as AAPL.US or 700.HK.",
                    ExitCode::from(2),
                );
            }
            if auth::status() != AuthState::Authenticated {
                return emit_error(
                    &mut output,
                    "not_authenticated",
                    "Connect your Longbridge account.",
                    ExitCode::from(3),
                );
            }
            let source = match SdkQuoteSource::connect().await {
                Ok(source) => source,
                Err(_) => {
                    return emit_error(
                        &mut output,
                        "connection_failed",
                        "Could not connect to Longbridge.",
                        ExitCode::from(4),
                    );
                }
            };
            match stream::run(source, symbols, &mut output).await {
                Ok(()) => ExitCode::SUCCESS,
                Err(_) => emit_error(
                    &mut output,
                    "stream_failed",
                    "The Longbridge quote stream stopped.",
                    ExitCode::from(5),
                ),
            }
        }
        Command::Auth { .. } | Command::Search { .. } => emit_error(
            &mut output,
            "not_implemented",
            "This helper command is not implemented yet.",
            ExitCode::from(6),
        ),
    }
}

fn emit(output: &mut impl io::Write, event: Event, success: ExitCode) -> ExitCode {
    if write_event(output, &event).is_ok() {
        success
    } else {
        ExitCode::from(1)
    }
}

fn emit_error(
    output: &mut impl io::Write,
    code: &str,
    message: &str,
    exit_code: ExitCode,
) -> ExitCode {
    emit(
        output,
        Event::Error(ErrorEvent {
            code: code.to_string(),
            message: message.to_string(),
        }),
        exit_code,
    )
}

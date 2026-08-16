use std::io::Write;

use anyhow::Context as _;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Event {
    Connection { state: String },
    Snapshot { quotes: Vec<Quote> },
    Quote(Quote),
    Subscription { symbols: Vec<String> },
    Auth { state: String, message: String },
    Search { results: Vec<SearchResult> },
    Error(ErrorEvent),
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Quote {
    pub symbol: String,
    pub name: String,
    pub currency: String,
    pub last: String,
    pub prev_close: String,
    pub open: String,
    pub high: String,
    pub low: String,
    pub volume: String,
    pub turnover: String,
    pub timestamp: i64,
    pub trade_status: String,
    pub trade_session: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SearchResult {
    pub symbol: String,
    pub name: String,
    pub market: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ErrorEvent {
    pub code: String,
    pub message: String,
}

pub fn write_event<W: Write>(output: &mut W, event: &Event) -> anyhow::Result<()> {
    serde_json::to_writer(&mut *output, event).context("failed to serialize helper event")?;
    output
        .write_all(b"\n")
        .context("failed to terminate helper event")?;
    output.flush().context("failed to flush helper event")
}

#[cfg(test)]
mod tests {
    use super::{write_event, ErrorEvent, Event, Quote};

    #[test]
    fn quote_decimals_are_json_strings() {
        let event = Event::Quote(Quote {
            symbol: "AAPL.US".to_string(),
            name: "Apple Inc.".to_string(),
            currency: "USD".to_string(),
            last: "232.18".to_string(),
            prev_close: "230.00".to_string(),
            open: "231.05".to_string(),
            high: "233.20".to_string(),
            low: "229.90".to_string(),
            volume: "1234567".to_string(),
            turnover: "286523456.78".to_string(),
            timestamp: 1_786_861_000,
            trade_status: "Normal".to_string(),
            trade_session: "Intraday".to_string(),
        });

        let value = serde_json::to_value(event).unwrap();
        assert_eq!(value["last"], "232.18");
        assert_eq!(value["turnover"], "286523456.78");
        assert!(value["last"].is_string());
    }

    #[test]
    fn writer_emits_exactly_one_line_per_event() {
        let mut output = Vec::new();
        write_event(
            &mut output,
            &Event::Connection {
                state: "connecting".to_string(),
            },
        )
        .unwrap();

        assert_eq!(
            String::from_utf8(output).unwrap(),
            "{\"type\":\"connection\",\"state\":\"connecting\"}\n"
        );
    }

    #[test]
    fn safe_error_has_no_extra_fields() {
        let value = serde_json::to_value(Event::Error(ErrorEvent {
            code: "not_authenticated".to_string(),
            message: "Connect your Longbridge account.".to_string(),
        }))
        .unwrap();

        assert_eq!(
            value,
            serde_json::json!({
                "type": "error",
                "code": "not_authenticated",
                "message": "Connect your Longbridge account."
            })
        );
    }
}

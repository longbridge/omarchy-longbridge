use std::collections::{HashMap, HashSet};
use std::io::Write;

use anyhow::bail;
use async_trait::async_trait;

use crate::protocol::{write_event, Event, Quote};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RawQuote {
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

impl From<RawQuote> for Quote {
    fn from(value: RawQuote) -> Self {
        Self {
            symbol: value.symbol,
            name: value.name,
            currency: value.currency,
            last: value.last,
            prev_close: value.prev_close,
            open: value.open,
            high: value.high,
            low: value.low,
            volume: value.volume,
            turnover: value.turnover,
            timestamp: value.timestamp,
            trade_status: value.trade_status,
            trade_session: value.trade_session,
        }
    }
}

#[async_trait]
pub trait QuoteSource {
    async fn snapshot(&mut self, symbols: &[String]) -> anyhow::Result<Vec<RawQuote>>;
    async fn subscribe(&mut self, symbols: &[String]) -> anyhow::Result<()>;
    async fn next_push(&mut self) -> Option<anyhow::Result<RawQuote>>;
}

pub async fn run<S, W>(
    mut source: S,
    requested_symbols: Vec<String>,
    mut output: W,
) -> anyhow::Result<()>
where
    S: QuoteSource,
    W: Write,
{
    let symbols = normalized_symbols(requested_symbols)?;
    write_event(
        &mut output,
        &Event::Connection {
            state: "connecting".to_string(),
        },
    )?;

    let snapshot = source.snapshot(&symbols).await?;
    let mut known = HashMap::new();
    for quote in &snapshot {
        known.insert(quote.symbol.clone(), quote.clone());
    }
    write_event(
        &mut output,
        &Event::Snapshot {
            quotes: snapshot.into_iter().map(Quote::from).collect(),
        },
    )?;

    source.subscribe(&symbols).await?;
    write_event(
        &mut output,
        &Event::Subscription {
            symbols: symbols.clone(),
        },
    )?;

    while let Some(push) = source.next_push().await {
        let mut push = push?;
        if let Some(previous) = known.get(&push.symbol) {
            preserve_snapshot_fields(&mut push, previous);
        }
        known.insert(push.symbol.clone(), push.clone());
        write_event(&mut output, &Event::Quote(push.into()))?;
    }
    Ok(())
}

pub fn normalized_symbols(symbols: Vec<String>) -> anyhow::Result<Vec<String>> {
    if symbols.is_empty() {
        bail!("at least one Longbridge symbol is required");
    }
    if symbols.len() > 20 {
        bail!("at most 20 Longbridge symbols are supported");
    }
    let mut seen = HashSet::new();
    let mut result = Vec::new();
    for value in symbols {
        let symbol = value.trim().to_ascii_uppercase();
        if !valid_symbol(&symbol) {
            bail!("invalid Longbridge symbol: {symbol}");
        }
        if seen.insert(symbol.clone()) {
            result.push(symbol);
        }
    }
    Ok(result)
}

fn valid_symbol(symbol: &str) -> bool {
    let Some((code, market)) = symbol.rsplit_once('.') else {
        return false;
    };
    !code.is_empty()
        && code.len() <= 20
        && code
            .bytes()
            .all(|byte| byte.is_ascii_uppercase() || byte.is_ascii_digit() || byte == b'-')
        && matches!(market, "US" | "HK" | "SH" | "SZ" | "SG")
}

fn preserve_snapshot_fields(push: &mut RawQuote, previous: &RawQuote) {
    if push.name.is_empty() {
        push.name.clone_from(&previous.name);
    }
    if push.currency.is_empty() {
        push.currency.clone_from(&previous.currency);
    }
    if push.prev_close.is_empty() {
        push.prev_close.clone_from(&previous.prev_close);
    }
}

#[cfg(test)]
mod tests {
    use std::collections::VecDeque;

    use async_trait::async_trait;

    use super::{run, QuoteSource, RawQuote};

    struct FakeSource {
        snapshot: Vec<RawQuote>,
        pushes: VecDeque<anyhow::Result<RawQuote>>,
        subscribed: Vec<String>,
    }

    #[async_trait]
    impl QuoteSource for FakeSource {
        async fn snapshot(&mut self, _symbols: &[String]) -> anyhow::Result<Vec<RawQuote>> {
            Ok(self.snapshot.clone())
        }

        async fn subscribe(&mut self, symbols: &[String]) -> anyhow::Result<()> {
            self.subscribed = symbols.to_vec();
            Ok(())
        }

        async fn next_push(&mut self) -> Option<anyhow::Result<RawQuote>> {
            self.pushes.pop_front()
        }
    }

    fn quote(symbol: &str, last: &str, previous: &str, timestamp: i64) -> RawQuote {
        RawQuote {
            symbol: symbol.to_string(),
            name: "Apple Inc.".to_string(),
            currency: "USD".to_string(),
            last: last.to_string(),
            prev_close: previous.to_string(),
            open: "226.00".to_string(),
            high: "233.20".to_string(),
            low: "225.50".to_string(),
            volume: "1234567".to_string(),
            turnover: "286523456.78".to_string(),
            timestamp,
            trade_status: "Normal".to_string(),
            trade_session: "Intraday".to_string(),
        }
    }

    #[tokio::test]
    async fn stream_emits_snapshot_subscription_and_merged_push_in_order() {
        let source = FakeSource {
            snapshot: vec![quote("AAPL.US", "230.00", "225.00", 100)],
            pushes: VecDeque::from([Ok(quote("AAPL.US", "232.18", "", 110))]),
            subscribed: Vec::new(),
        };
        let mut output = Vec::new();

        run(source, vec!["aapl.us".to_string()], &mut output)
            .await
            .unwrap();

        let events: Vec<serde_json::Value> = String::from_utf8(output)
            .unwrap()
            .lines()
            .map(|line| serde_json::from_str(line).unwrap())
            .collect();
        assert_eq!(
            events
                .iter()
                .map(|event| event["type"].as_str().unwrap())
                .collect::<Vec<_>>(),
            ["connection", "snapshot", "subscription", "quote"]
        );
        assert_eq!(events[3]["symbol"], "AAPL.US");
        assert_eq!(events[3]["last"], "232.18");
        assert_eq!(events[3]["prev_close"], "225.00");
    }

    #[tokio::test]
    async fn duplicate_and_invalid_symbols_are_rejected_before_network_use() {
        let source = FakeSource {
            snapshot: Vec::new(),
            pushes: VecDeque::new(),
            subscribed: Vec::new(),
        };
        let mut output = Vec::new();

        let error = run(
            source,
            vec![
                "AAPL.US".to_string(),
                "AAPL.US".to_string(),
                "AAPL".to_string(),
            ],
            &mut output,
        )
        .await
        .unwrap_err();

        assert_eq!(error.to_string(), "invalid Longbridge symbol: AAPL");
        assert!(output.is_empty());
    }
}

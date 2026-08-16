//! Longbridge quote context adapter.

use std::collections::HashMap;
use std::sync::Arc;

use async_trait::async_trait;
use longbridge::quote::{PushEventDetail, SecurityQuote, SecurityStaticInfo, SubFlags};
use tokio::sync::mpsc;

use crate::auth::{self, AuthState};
use crate::secure_storage::EncryptedFileTokenStorage;
use crate::stream::{QuoteSource, RawQuote};

pub struct SdkQuoteSource {
    context: longbridge::quote::QuoteContext,
    receiver: mpsc::UnboundedReceiver<longbridge::quote::PushEvent>,
}

impl SdkQuoteSource {
    pub async fn connect() -> anyhow::Result<Self> {
        if auth::status() != AuthState::Authenticated {
            anyhow::bail!("not authenticated");
        }
        let client_id = auth::effective_client_id();
        let oauth = longbridge::oauth::OAuthBuilder::new(client_id)
            .callback_port(60_355)
            .token_storage(EncryptedFileTokenStorage)
            .build(|_| {})
            .await
            .map_err(|error| anyhow::anyhow!("OAuth initialization failed: {error}"))?;
        let config = Arc::new(
            longbridge::Config::from_oauth(oauth)
                .enable_overnight()
                .dont_print_quote_packages(),
        );
        let (context, receiver) = longbridge::quote::QuoteContext::new(config);
        Ok(Self { context, receiver })
    }
}

#[async_trait]
impl QuoteSource for SdkQuoteSource {
    async fn snapshot(&mut self, symbols: &[String]) -> anyhow::Result<Vec<RawQuote>> {
        let identities = self.context.static_info(symbols).await?;
        let identity_by_symbol: HashMap<String, SecurityStaticInfo> = identities
            .into_iter()
            .map(|identity| (identity.symbol.clone(), identity))
            .collect();
        let snapshots = self.context.quote(symbols).await?;
        Ok(snapshots
            .into_iter()
            .map(|snapshot| {
                let identity = identity_by_symbol.get(&snapshot.symbol);
                snapshot_to_raw(snapshot, identity)
            })
            .collect())
    }

    async fn subscribe(&mut self, symbols: &[String]) -> anyhow::Result<()> {
        self.context.subscribe(symbols, SubFlags::QUOTE).await?;
        Ok(())
    }

    async fn next_push(&mut self) -> Option<anyhow::Result<RawQuote>> {
        while let Some(event) = self.receiver.recv().await {
            if let PushEventDetail::Quote(quote) = event.detail {
                return Some(Ok(RawQuote {
                    symbol: event.symbol,
                    name: String::new(),
                    currency: String::new(),
                    last: quote.last_done.to_string(),
                    prev_close: String::new(),
                    open: quote.open.to_string(),
                    high: quote.high.to_string(),
                    low: quote.low.to_string(),
                    volume: quote.volume.to_string(),
                    turnover: quote.turnover.to_string(),
                    timestamp: quote.timestamp.unix_timestamp(),
                    trade_status: format!("{:?}", quote.trade_status),
                    trade_session: format!("{:?}", quote.trade_session),
                }));
            }
        }
        None
    }
}

fn snapshot_to_raw(snapshot: SecurityQuote, identity: Option<&SecurityStaticInfo>) -> RawQuote {
    RawQuote {
        symbol: snapshot.symbol,
        name: identity
            .map(|value| value.name_en.clone())
            .unwrap_or_default(),
        currency: identity
            .map(|value| value.currency.clone())
            .unwrap_or_default(),
        last: snapshot.last_done.to_string(),
        prev_close: snapshot.prev_close.to_string(),
        open: snapshot.open.to_string(),
        high: snapshot.high.to_string(),
        low: snapshot.low.to_string(),
        volume: snapshot.volume.to_string(),
        turnover: snapshot.turnover.to_string(),
        timestamp: snapshot.timestamp.unix_timestamp(),
        trade_status: format!("{:?}", snapshot.trade_status),
        trade_session: String::new(),
    }
}

#[cfg(test)]
mod tests {
    use longbridge::quote::{
        DerivativeType, SecurityBoard, SecurityQuote, SecurityStaticInfo, TradeStatus,
    };
    use rust_decimal::Decimal;
    use time::OffsetDateTime;

    use super::snapshot_to_raw;

    #[test]
    fn sdk_snapshot_conversion_preserves_decimal_strings_and_identity() {
        let snapshot = SecurityQuote {
            symbol: "AAPL.US".to_string(),
            last_done: Decimal::new(23218, 2),
            prev_close: Decimal::new(22500, 2),
            open: Decimal::new(22600, 2),
            high: Decimal::new(23320, 2),
            low: Decimal::new(22550, 2),
            timestamp: OffsetDateTime::from_unix_timestamp(1_786_861_000).unwrap(),
            volume: 1_234_567,
            turnover: Decimal::new(28_652_345_678, 2),
            trade_status: TradeStatus::Normal,
            pre_market_quote: None,
            post_market_quote: None,
            overnight_quote: None,
        };
        let identity = SecurityStaticInfo {
            symbol: "AAPL.US".to_string(),
            name_cn: "苹果".to_string(),
            name_en: "Apple Inc.".to_string(),
            name_hk: "蘋果".to_string(),
            exchange: "NASDAQ".to_string(),
            currency: "USD".to_string(),
            lot_size: 1,
            total_shares: 0,
            circulating_shares: 0,
            hk_shares: 0,
            eps: Decimal::ZERO,
            eps_ttm: Decimal::ZERO,
            bps: Decimal::ZERO,
            dividend_yield: Decimal::ZERO,
            stock_derivatives: DerivativeType::empty(),
            board: SecurityBoard::Unknown,
        };

        let actual = snapshot_to_raw(snapshot, Some(&identity));
        assert_eq!(actual.symbol, "AAPL.US");
        assert_eq!(actual.name, "Apple Inc.");
        assert_eq!(actual.currency, "USD");
        assert_eq!(actual.last, "232.18");
        assert_eq!(actual.turnover, "286523456.78");
        assert_eq!(actual.timestamp, 1_786_861_000);
    }
}

# RSI+MA Combo EA (MetaTrader 4)

## Overview
A robust Expert Advisor for MT4 that combines RSI, Moving Average, and ADX indicators, with trailing stop, break-even, daily trading limits, time filters, dynamic exit, and safety features.

## Features
- **Signal Entry:**  
  - Buy/Sell on RSI+MA+ADX conditions
- **Trade Management:**  
  - Trailing stop, break-even, dynamic exit (multi-bar confirmation + ADX strength)
- **Risk Controls:**  
  - Daily profit/loss pause (with colored chart label)
  - Time filter (trading hours)
- **Magic Number:**  
  - Prevents trade conflicts with other EAs
- **Broker Safety:**  
  - Checks minimum stop levels before sending orders

## Inputs

| Parameter           | Description                       |
|---------------------|-----------------------------------|
| LotSize             | Trading lot size                  |
| RSI_Period          | RSI period                        |
| RSI_Buy_Level       | RSI value for buy                 |
| RSI_Sell_Level      | RSI value for sell                |
| MA_Period           | MA period                         |
| StopLossPips        | Stop loss in pips                 |
| TakeProfitPips      | Take profit in pips               |
| UseTrailingStop     | Enable trailing stop              |
| TrailingStart       | Start trailing at X pips          |
| TrailingStep        | Trail step in pips                |
| UseBreakEven        | Enable break-even                 |
| BreakEvenTrigger    | Profit (pips) to trigger BE       |
| BreakEvenOffset     | BE offset in pips                 |
| UseTimeFilter       | Trade only within hours           |
| TradeStartHour      | Trade start hour                  |
| TradeEndHour        | Trade end hour                    |
| UseADXFilter        | Enable ADX filter                 |
| ADX_Period          | ADX period                        |
| ADX_Minimum         | Minimum ADX for entry             |
| UseDailyLimit       | Enable daily profit/loss pause    |
| DailyProfitTarget   | Profit to pause for the day (USD) |
| DailyLossLimit      | Loss to pause for the day (USD)   |
| PauseDurationHours  | Pause duration (hours)            |
| UseDynamicExit      | Enable dynamic exit               |
| ConfirmBars         | Bars to confirm exit              |
| ADXExitThreshold    | Minimum ADX for exit              |
| MagicNumber         | Unique EA identifier              |

## Trading Logic
- **Entry:**  
  - Buy: RSI <= Buy Level, price > MA, +DI > -DI, ADX > threshold
  - Sell: RSI >= Sell Level, price < MA, -DI > +DI, ADX > threshold
  - Trades only once per bar
  - Only one buy or sell order open at a time
  - Only trades during defined hours and when not paused by daily limits

- **Management:**  
  - Break-even and trailing stop checks broker's minimum stop level
  - Dynamic exit: closes trades early if the opposite signal is confirmed for X bars, with sufficient ADX strength

- **Daily Limits:**  
  - If profit/loss exceeds target, trading is paused for set hours

## Installation
1. Copy `RSI_MA_Combo_EA.mq4` to your MT4 `/experts/` directory
2. Restart MetaTrader 4
3. Attach EA to chart and configure inputs

## Safety Notes
- Always use a unique MagicNumber if running multiple EAs
- Check broker's minimum stop level requirements
- Test thoroughly on demo account before live trading

## Changelog

**2025-10-04**
- Improved error handling
- Added Magic Number logic
- Broker stop level compliance
- Prevent duplicate entries per bar
- Robust trade management

## License

MIT# rsi-ma-combo-ea

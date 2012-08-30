# About

It's a scalping EA (Expert Advisor) for MetaTrader4, use to trade on two or more brokers. EA check the price of two brokers with the help of MySQL, if the price difference is big enough (you can set), open order on these brokers at same time, one Buy order and one Sell order, then when total profit greater than your target (you can set too) close orders at same time too. It can run on any symbol.


# Getting started

You need two brokers MetaTrader4 account first.

## Install

- Install MySQL 5.5 Server on your computer. [MySQL](http://www.mysql.com/)
- Copy the "experts" forder to both your two broker's MateTrader4 installation folder.
- Restart your two MateTrader4 terminal.

## Config

### Setup slave client

- Open one broker's MetaTrader4 and new a chart (any symbol any periodicity).
- Load EA 'nst_mbt_slave' from Navigator.
- Setup your MySQL settings (user, password, host.....).
- Press OK.

### Setup master client

- Open another broker's MetaTrader4 and new a chart same to the slave client.
- Load EA 'nst_mbt_master' from Navigator.
- Setup your MySQL settings (user, password, host.....).
- Setup slave client info, broker's name and account number. You can copy & paste it from your MySQL.
- Press OK, done.
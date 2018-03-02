# About

Nerr Smart Trader - Multi Broker Trader

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

## Thanks
Thank [Navicat](http://www.navicat.com) for the [Open Source Project License](http://www.navicat.com/store/open-source) support.

[![Logo](https://raw.githubusercontent.com/nerr/nst_mbt/master/docs/logo/navicat.png)](http://www.navicat.com)

Thank [RubyMine](http://www.jetbrains.com/ruby/) for the [Open Source Project License](http://www.jetbrains.com/ruby/buy/buy.jsp#openSource) support.

[![Logo](http://www.jetbrains.com/img/logos/rubymine_logo142x29.gif)](http://www.jetbrains.com/ruby)

# License

	Copyright (c) 2018 Nerrsoft.com

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at

		http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
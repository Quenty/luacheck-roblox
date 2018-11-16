## Roblox Luacheck
<div align="center">
	<a href="https://discord.gg/mhtGUS8">
		<img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
	</a>
</div>

Generates the `roblox_standard.lua` file necessary to provide support for Roblox Lua in Luacheck.

## Features

* Automatically applies `script` and `workspace` properties
* Automatically applies the `Enum` namespace
* Has definitions for Roblox types and variables
* Specifically ignores adding `Workspace` and other global variables following Roblox's standards

## Run
To run you need Lua (5.1 or higher).

## Usage
You can copy the contents of `roblox_standard.lua` into your `.luacheckrc`


Inspired by https://github.com/Positive07/luacheck-love
"""POPOPX Config Bot — server configuration and bot directory distribution.

Replaces the centralized REST API (api.popopxchat.com/api/v1/servers/config)
with a POPOPX bot that serves configuration via chat commands.

Commands (via POPOPX chat):
  /config  — return full server configuration as JSON
  /ice     — return ICE servers only
  /bots    — return bot directory listing
  /ping    — health check
  /help    — usage info

The config JSON includes:
  - ice_servers: WebRTC STUN/TURN servers
  - preset_operators: SMP + XFTP server operators
  - bot_directory: available service bots with pricing

Security:
  - Read-only: bot only serves static config, accepts no user data
  - Config is embedded in the script (or loaded from config.json)
  - No authentication needed — config is public
"""

from __future__ import annotations

import json
import os

from popopx_chat import (
    Bot,
    BotCommand,
    BotProfile,
    Message,
    ParsedCommand,
    SqliteDb,
)

CONFIG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json")

DEFAULT_CONFIG = {
    "ice_servers": [
        "stun:stun.popopxchat.com:443",
        "turns:turn.popopxchat.com:443?transport=tcp"
    ],
    "chat_relays": [
        {
            "name": "PopopX Chat Relay 1",
            "url": "https://smp1.popopxchat.com/r#Kz9xR4vP2mN5qW7jL9hT3fY6cB0dA8gE1iO4kM7nPxQ=",
            "domains": ["popopxchat.com"],
            "enabled": True
        },
        {
            "name": "PopopX Chat Relay 2",
            "url": "https://smp55.popopxchat.com/r#Fp5RWXkiRFg-hgcDwC2v-MWnPfvEf42RgCqREntW0mw",
            "domains": ["popopxchat.com"],
            "enabled": True
        },
        {
            "name": "PopopX Chat Relay 3",
            "url": "https://smp65.popopxchat.com/r#_qlQfogHGDJ8MAF2wKmkglRBM-xHR142gDJstKiGRQQ",
            "domains": ["popopxchat.com"],
            "enabled": True
        },
        {
            "name": "PopopX Chat Relay 4",
            "url": "https://smp44.popopxchat.com/r#yxNOMJcry5jMTRPEBVtGBATYaKeoRIsZRBPIDLx7x6M",
            "domains": ["popopxchat.com"],
            "enabled": True
        }
    ],
    "preset_operators": [
        {
            "operator_tag": "popopx",
            "trade_name": "PopopX Switch",
            "smp_servers": [
                "smp://q5TvFxQPkloaEGYhlLHejVWW7K31C57wq-YXjuwb258=@smp1.popopxchat.com,5eyw2zx2lykj6y6emgupunlldr7say3q5plkknvv6dddka5kcls63oqd.onion",
                "smp://h87w8XV_Q8bczkZvugDVB7RmqqpmBhIbgqYgXeZaQ4k=@ps1.popopxchat.xyz,2i2xq2epnpz43vuz7xzu74ewcfsmagbf4fytmcyayhuhhwc3thnq7fqd.onion",
                "smp://H7mJ2kP9xR4vT6wZ0cB3dA8fG1iO5qR9sV2wX7yZ4mN=@smp3.popopxchat.com,p5q8r1s4v7w0x3y6z9a2b5c8d1f4g7i0o3r6s9v2w5x.onion",
                "smp://Q5nL8jK2mP6xR9vT4wZ0cB3dA7fG1iO5qR9sV2wX8yZ=@smp4.popopxchat.com,q2r5s8v1w4x7y0z3a6b9c2d5f8g1i4o7r0s3v6w9x2y.onion"
            ],
            "xftp_servers": [
                "xftp://R8vT2mN5qW7jL9hK3xP4fY6cB0dA1gE8iO4kM7nPxQz=@xftp1.popopxchat.com,r4s7v0w3x6y9z2a5b8c1d4f7g0i3o6r9s2v5w8x1y4z.onion",
                "xftp://J6kL2mP9xR4vT8wZ0cB3dA5fG7iO1qR5sV9wX2yZ6mN=@xftp2.popopxchat.com,t1u4x7y0z3a6b9c2d5f8g1i4o7r0s3v6w9x2y5z8a1b.onion",
                "xftp://M3nQ7rS2vW5xY8zA1bC4dF6gI0kO3pR6sV9wX2yZ5mN=@xftp3.popopxchat.com,u8a1b4c7d0f3g6i9o2p5r8s1v4w7x0y3z6a9b2c5d8f.onion"
            ]
        }
    ],
    "bot_directory": [
        {
            "bot_address": "",
            "bot_name": "BinThere",
            "bot_type": "binthere",
            "description": "Burn-after-read encrypted messaging",
            "icon_url": None,
            "token_count": 0,
            "pricing_unit": None,
            "pricing_amount": 0
        }
    ]
}


def load_config() -> dict:
    """Load config from config.json if it exists, otherwise use defaults."""
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return DEFAULT_CONFIG


bot = Bot(
    profile=BotProfile(display_name="POPOPX Config"),
    db=SqliteDb(file_prefix="./config_bot"),
    welcome="POPOPX configuration bot. Use /help for commands.",
    commands=[
        BotCommand(keyword="config", label="Get full server configuration"),
        BotCommand(keyword="ice", label="Get ICE servers only"),
        BotCommand(keyword="bots", label="Get bot directory"),
        BotCommand(keyword="ping", label="Health check"),
        BotCommand(keyword="help", label="Show help"),
    ],
)


@bot.on_command("help")
async def help_cmd(msg: Message, _cmd: ParsedCommand) -> None:
    await msg.reply(
        "POPOPX Config Bot\n\n"
        "/config — Full server configuration (JSON)\n"
        "/ice — ICE servers only (JSON)\n"
        "/bots — Bot directory listing (JSON)\n"
        "/ping — Health check\n"
        "/help — Show this message"
    )


@bot.on_command("config")
async def config_cmd(msg: Message, _cmd: ParsedCommand) -> None:
    config = load_config()
    await msg.reply(json.dumps(config, ensure_ascii=False))


@bot.on_command("ice")
async def ice_cmd(msg: Message, _cmd: ParsedCommand) -> None:
    config = load_config()
    await msg.reply(json.dumps({"ice_servers": config.get("ice_servers", [])}, ensure_ascii=False))


@bot.on_command("bots")
async def bots_cmd(msg: Message, _cmd: ParsedCommand) -> None:
    config = load_config()
    await msg.reply(json.dumps({"bot_directory": config.get("bot_directory", [])}, ensure_ascii=False))


@bot.on_command("ping")
async def ping_cmd(msg: Message, _cmd: ParsedCommand) -> None:
    await msg.reply("pong")


@bot.on_message(content_type="text")
async def fallback(msg: Message) -> None:
    await msg.reply("Use /help to see available commands.")


if __name__ == "__main__":
    bot.run()

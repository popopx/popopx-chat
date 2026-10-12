"""BinThere bot — encrypted burn-after-read paste storage.

A zero-knowledge paste gateway: stores AES-256-GCM ciphertext blobs and
serves them with a lock→confirm→burn protocol. The bot never sees plaintext
or decryption keys.

Commands (via SimpleX chat):
  /store <base64_ciphertext>  — store encrypted paste, reply STORED:<id>
  /get <paste_id>             — lock and return ciphertext, reply LOCKED:<id>:<data>
  /burned <paste_id>          — confirm reader got it, permanently delete
  /help                       — usage info

Protocol:
  1. /get locks the paste (status='locked') and returns ciphertext
  2. Client decrypts successfully, then sends /burned to confirm
  3. /burned permanently deletes the paste
  4. If no /burned within 5 minutes, lock expires and paste can be re-read
  5. 24h auto-expiry for all pastes regardless

Security:
  - paste_id: 128-bit random (secrets.token_urlsafe(16))
  - Lock prevents concurrent reads (single consumer)
  - Auto-unlock after 5min prevents data loss from network failures
  - Bot has zero knowledge: only stores opaque ciphertext
"""

from __future__ import annotations

import secrets
import sqlite3
import threading
import time

from simplex_chat import (
    Bot,
    BotCommand,
    BotProfile,
    Message,
    ParsedCommand,
    SqliteDb,
)

DEFAULT_TTL = 86400
CLEANUP_INTERVAL = 60
LOCK_TIMEOUT = 300  # 5 minutes

bot = Bot(
    profile=BotProfile(display_name="BinThere"),
    db=SqliteDb(file_prefix="./binthere_bot"),
    welcome="I store burn-after-read messages. Use /help for commands.",
    commands=[
        BotCommand(keyword="help", label="Show help"),
        BotCommand(keyword="store", label="Store encrypted paste", params="<ciphertext>"),
        BotCommand(keyword="get", label="Retrieve paste (locks it)", params="<paste_id>"),
        BotCommand(keyword="burned", label="Confirm paste destroyed", params="<paste_id>"),
    ],
)


class PasteStore:
    """SQLite-backed paste storage with lock/confirm/burn and auto-expiry."""

    def __init__(self, db_path: str = "./binthere_pastes.db"):
        self.conn = sqlite3.connect(db_path, check_same_thread=False)
        self.lock = threading.Lock()
        self._init_schema()
        self._start_cleanup_thread()

    def _init_schema(self):
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS pastes (
                id TEXT PRIMARY KEY,
                ciphertext TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                expires_at INTEGER NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                locked_at INTEGER
            )
        """)
        self.conn.commit()
        try:
            self.conn.execute("ALTER TABLE pastes ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'")
            self.conn.commit()
        except sqlite3.OperationalError:
            pass
        try:
            self.conn.execute("ALTER TABLE pastes ADD COLUMN locked_at INTEGER")
            self.conn.commit()
        except sqlite3.OperationalError:
            pass

    def _start_cleanup_thread(self):
        def cleanup_loop():
            while True:
                time.sleep(CLEANUP_INTERVAL)
                self.cleanup_expired()

        t = threading.Thread(target=cleanup_loop, daemon=True)
        t.start()

    def cleanup_expired(self):
        now = int(time.time())
        with self.lock:
            self.conn.execute("DELETE FROM pastes WHERE expires_at < ?", (now,))
            self.conn.execute(
                "UPDATE pastes SET status = 'pending', locked_at = NULL "
                "WHERE status = 'locked' AND locked_at IS NOT NULL AND locked_at < ?",
                (now - LOCK_TIMEOUT,),
            )
            self.conn.commit()

    def store(self, ciphertext_b64: str, ttl: int = DEFAULT_TTL) -> str:
        paste_id = secrets.token_urlsafe(16)
        now = int(time.time())
        expires_at = now + ttl
        with self.lock:
            self.conn.execute(
                "INSERT INTO pastes (id, ciphertext, created_at, expires_at) VALUES (?, ?, ?, ?)",
                (paste_id, ciphertext_b64, now, expires_at),
            )
            self.conn.commit()
        return paste_id

    def get_and_lock(self, paste_id: str) -> str | None:
        """Lock a paste for reading. Returns ciphertext or None.

        - If paste doesn't exist or is burned: return None
        - If paste is expired: delete and return None
        - If paste is locked and lock hasn't expired: return None (someone else has it)
        - If paste is locked but lock expired: allow re-read (re-lock)
        - Otherwise: lock and return ciphertext
        """
        now = int(time.time())
        with self.lock:
            cursor = self.conn.execute(
                "SELECT ciphertext, expires_at, status, locked_at FROM pastes WHERE id = ?",
                (paste_id,),
            )
            row = cursor.fetchone()
            if row is None:
                return None
            ciphertext_b64, expires_at, status, locked_at = row
            if expires_at < now:
                self.conn.execute("DELETE FROM pastes WHERE id = ?", (paste_id,))
                self.conn.commit()
                return None
            if status == "burned":
                return None
            if status == "locked":
                if locked_at is not None and (now - locked_at) < LOCK_TIMEOUT:
                    return None
            self.conn.execute(
                "UPDATE pastes SET status = 'locked', locked_at = ? WHERE id = ?",
                (now, paste_id),
            )
            self.conn.commit()
            return ciphertext_b64

    def burn(self, paste_id: str) -> bool:
        """Permanently delete a paste."""
        with self.lock:
            self.conn.execute("DELETE FROM pastes WHERE id = ?", (paste_id,))
            self.conn.commit()
            return self.conn.total_changes > 0


store = PasteStore()


@bot.on_command("help")
async def help_cmd(msg: Message, _cmd: ParsedCommand) -> None:
    await msg.reply(
        "BinThere — Burn-after-read storage\n\n"
        "/store <ciphertext> — Store encrypted paste\n"
        "/get <paste_id> — Lock and retrieve paste\n"
        "/burned <paste_id> — Confirm destruction\n\n"
        "Lock expires after 5 minutes if not confirmed.\n"
        "All content is encrypted client-side. I only store ciphertext."
    )


@bot.on_command("store")
async def store_cmd(msg: Message, cmd: ParsedCommand) -> None:
    ciphertext_b64 = cmd.args.strip()
    if not ciphertext_b64:
        await msg.reply("Usage: /store <base64_ciphertext>")
        return
    if len(ciphertext_b64) > 3_000_000:
        await msg.reply("Error: paste too large (max 3MB)")
        return
    paste_id = store.store(ciphertext_b64)
    await msg.reply(f"STORED:{paste_id}")


@bot.on_command("get")
async def get_cmd(msg: Message, cmd: ParsedCommand) -> None:
    paste_id = cmd.args.strip()
    if not paste_id:
        await msg.reply("Usage: /get <paste_id>")
        return
    ciphertext_b64 = store.get_and_lock(paste_id)
    if ciphertext_b64 is None:
        await msg.reply(f"GONE:{paste_id}")
        return
    await msg.reply(f"LOCKED:{paste_id}:{ciphertext_b64}")


@bot.on_command("burned")
async def burned_cmd(msg: Message, cmd: ParsedCommand) -> None:
    paste_id = cmd.args.strip()
    if not paste_id:
        await msg.reply("Usage: /burned <paste_id>")
        return
    store.burn(paste_id)
    await msg.reply(f"BURNED:{paste_id}")


@bot.on_message(content_type="text")
async def fallback(msg: Message) -> None:
    await msg.reply("Use /help to see available commands.")


if __name__ == "__main__":
    bot.run()

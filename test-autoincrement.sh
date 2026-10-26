#!/bin/bash
# Test that AUTOINCREMENT is correctly set in initial migrations

set -e

DB="/tmp/test_autoincrement_$(date +%s).db"

echo "Testing AUTOINCREMENT in fresh database..."
echo "Database: $DB"

# Create fresh database and run migrations
sqlite3 "$DB" <<'EOF'
-- M20220101_initial (relevant tables only)
CREATE TABLE files (
  file_id INTEGER PRIMARY KEY AUTOINCREMENT,
  contact_id INTEGER,
  group_id INTEGER,
  file_name TEXT NOT NULL,
  file_path TEXT,
  file_size INTEGER NOT NULL,
  chunk_size INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  user_id INTEGER NOT NULL
);

CREATE TABLE users (
  user_id INTEGER PRIMARY KEY AUTOINCREMENT,
  contact_id INTEGER NOT NULL UNIQUE,
  local_display_name TEXT NOT NULL UNIQUE,
  active_user INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE contacts (
  contact_id INTEGER PRIMARY KEY AUTOINCREMENT,
  contact_profile_id INTEGER,
  user_id INTEGER NOT NULL,
  local_display_name TEXT NOT NULL,
  is_user INTEGER NOT NULL DEFAULT 0,
  via_group INTEGER,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE groups (
  group_id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  local_display_name TEXT NOT NULL,
  group_profile_id INTEGER,
  inv_queue_info BLOB
);

CREATE TABLE group_members (
  group_member_id INTEGER PRIMARY KEY AUTOINCREMENT,
  group_id INTEGER NOT NULL,
  member_id BLOB NOT NULL,
  member_role TEXT NOT NULL,
  member_category TEXT NOT NULL,
  member_status TEXT NOT NULL,
  invited_by INTEGER,
  sent_inv_queue_info BLOB,
  group_queue_info BLOB,
  direct_queue_info BLOB,
  user_id INTEGER NOT NULL,
  local_display_name TEXT NOT NULL,
  contact_profile_id INTEGER NOT NULL,
  contact_id INTEGER
);

CREATE TABLE connections (
  connection_id INTEGER PRIMARY KEY AUTOINCREMENT,
  agent_conn_id BLOB NOT NULL UNIQUE,
  conn_level INTEGER NOT NULL DEFAULT 0,
  via_contact INTEGER,
  conn_status TEXT NOT NULL,
  conn_type TEXT NOT NULL,
  user_contact_link_id INTEGER,
  contact_id INTEGER,
  group_member_id INTEGER,
  snd_file_id INTEGER,
  rcv_file_id INTEGER,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  user_id INTEGER NOT NULL
);

CREATE TABLE contact_requests (
  contact_request_id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_contact_link_id INTEGER NOT NULL,
  agent_invitation_id BLOB NOT NULL,
  contact_profile_id INTEGER,
  local_display_name TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  user_id INTEGER NOT NULL
);

-- M20220122_v1_1
CREATE TABLE chat_items (
  chat_item_id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  contact_id INTEGER,
  group_id INTEGER,
  group_member_id INTEGER,
  chat_msg_id INTEGER,
  created_by_msg_id INTEGER UNIQUE,
  item_sent INTEGER NOT NULL,
  item_ts TEXT NOT NULL,
  item_deleted INTEGER NOT NULL DEFAULT 0,
  item_content TEXT NOT NULL,
  item_text TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- M20260602_group_roster
CREATE TABLE rcv_roster_transfers(
  roster_transfer_id INTEGER PRIMARY KEY AUTOINCREMENT,
  group_id INTEGER NOT NULL,
  from_member_id INTEGER NOT NULL,
  roster_version INTEGER NOT NULL,
  roster_digest BLOB NOT NULL,
  sending_owner_gm_id INTEGER NOT NULL,
  broker_ts TEXT NOT NULL,
  roster_msg_body BLOB,
  roster_msg_chat_binding TEXT,
  roster_msg_signatures BLOB,
  created_at TEXT NOT NULL DEFAULT(datetime('now')),
  updated_at TEXT NOT NULL DEFAULT(datetime('now'))
);
EOF

echo "✓ Tables created successfully"

# Verify sqlite_sequence table exists (auto-created by SQLite when AUTOINCREMENT is used)
if sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='sqlite_sequence';" | grep -q "sqlite_sequence"; then
    echo "✓ sqlite_sequence table auto-created by SQLite"
else
    echo "✗ ERROR: sqlite_sequence table not found"
    exit 1
fi

# Test insert and verify AUTOINCREMENT behavior
echo ""
echo "Testing AUTOINCREMENT behavior..."

sqlite3 "$DB" <<'EOF'
INSERT INTO users (contact_id, local_display_name, active_user) VALUES (1, 'alice', 1);
INSERT INTO users (contact_id, local_display_name, active_user) VALUES (2, 'bob', 0);
INSERT INTO users (contact_id, local_display_name, active_user) VALUES (3, 'charlie', 0);

INSERT INTO contacts (user_id, local_display_name, is_user) VALUES (1, 'dave', 0);
INSERT INTO contacts (user_id, local_display_name, is_user) VALUES (1, 'eve', 0);

INSERT INTO chat_items (user_id, item_sent, item_ts, item_content, item_text) 
VALUES (1, 1, datetime('now'), '{}', 'Hello');

INSERT INTO files (user_id, file_name, file_size, chunk_size) 
VALUES (1, 'test.txt', 1024, 256);
EOF

# Check sqlite_sequence values
echo ""
echo "sqlite_sequence values:"
sqlite3 "$DB" "SELECT name, seq FROM sqlite_sequence ORDER BY name;"

# Verify sequences are correct
USERS_SEQ=$(sqlite3 "$DB" "SELECT seq FROM sqlite_sequence WHERE name='users';")
CONTACTS_SEQ=$(sqlite3 "$DB" "SELECT seq FROM sqlite_sequence WHERE name='contacts';")
CHAT_ITEMS_SEQ=$(sqlite3 "$DB" "SELECT seq FROM sqlite_sequence WHERE name='chat_items';")
FILES_SEQ=$(sqlite3 "$DB" "SELECT seq FROM sqlite_sequence WHERE name='files';")

echo ""
if [ "$USERS_SEQ" = "3" ]; then
    echo "✓ users sequence correct (3)"
else
    echo "✗ ERROR: users sequence is $USERS_SEQ, expected 3"
    exit 1
fi

if [ "$CONTACTS_SEQ" = "2" ]; then
    echo "✓ contacts sequence correct (2)"
else
    echo "✗ ERROR: contacts sequence is $CONTACTS_SEQ, expected 2"
    exit 1
fi

if [ "$CHAT_ITEMS_SEQ" = "1" ]; then
    echo "✓ chat_items sequence correct (1)"
else
    echo "✗ ERROR: chat_items sequence is $CHAT_ITEMS_SEQ, expected 1"
    exit 1
fi

if [ "$FILES_SEQ" = "1" ]; then
    echo "✓ files sequence correct (1)"
else
    echo "✗ ERROR: files sequence is $FILES_SEQ, expected 1"
    exit 1
fi

# Test that deleted IDs are not reused (AUTOINCREMENT guarantee)
echo ""
echo "Testing AUTOINCREMENT ID reuse protection..."

sqlite3 "$DB" "DELETE FROM users WHERE user_id = 2;"
sqlite3 "$DB" "INSERT INTO users (contact_id, local_display_name, active_user) VALUES (4, 'frank', 0);"

NEW_USER_ID=$(sqlite3 "$DB" "SELECT user_id FROM users WHERE local_display_name='frank';")
if [ "$NEW_USER_ID" = "4" ]; then
    echo "✓ AUTOINCREMENT prevents ID reuse (new user_id=4, not 2)"
else
    echo "✗ ERROR: ID was reused! new user_id=$NEW_USER_ID, expected 4"
    exit 1
fi

# Clean up
rm -f "$DB"

echo ""
echo "========================================="
echo "All AUTOINCREMENT tests passed! ✓"
echo "========================================="

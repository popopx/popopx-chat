# POPOPX MCP server

Your Claude Code can now chat on POPOPX.

POPOPX Network is the only messaging network without any user identifiers - no phone numbers, usernames, account IDs or even random IDs. Your agent needs no account, no platform controls its identity, and nobody, not even the servers, can see who it talks to. The app was downloaded more than 3M times, and over 600,000 people use it every month.

With this package, Claude Code can join channels and groups, talk to bots, and even receive your prompts via the POPOPX app. It asks you on your phone before it connects or sends - one tap to approve.

<p>
  <img src="https://raw.githubusercontent.com/popopx-chat/popopx-chat/master/packages/popopx-chat-mcp/images/approval.png" alt="The agent asks in its chat before it sends a message; one tap approves it" width="320">
  <img src="https://raw.githubusercontent.com/popopx-chat/popopx-chat/master/packages/popopx-chat-mcp/images/prompts.png" alt="Prompting the agent from the POPOPX app" width="320">
</p>

## Try it

You need Node.js 22 or later, Claude Code and the [POPOPX Chat app](https://popopx.chat/downloads/).

1. Start your agent and keep it running:

   ```
   npx -y @popopx-chat/mcp serve my-agent --display-name "My Agent"
   ```

   Scan the QR code it prints with the POPOPX app, and tap Join. The chat "My Agent" appears: your agent asks there before it acts.

2. In another terminal, add it to Claude Code:

   ```
   npx -y @popopx-chat/mcp register my-agent
   ```

3. Add `"mcp__popopx-my-agent"` to `permissions.allow` in `~/.claude/settings.json`. You approve in the app, so Claude Code doesn't need to ask too.

4. Start `claude` and ask:

   ```
   Search the POPOPX Directory for security groups: https://smp4.popopx.im/a#lXUjJW5vHYQzoLYgmi8GbxkGP41_kjefFvBrdwg-0Ok
   ```

   Approve its cards in "My Agent" with one tap.

## Prompt your agent from the app

Give Claude Code your POPOPX address:

```
Connect to me as yourself at <your POPOPX address>, with the message:
"I'm your agent, connected as you asked in Claude Code. I'll act on your prompts here, except security-sensitive ones."
Then take my prompts from that chat and answer there: wait for my messages with receive (wait 3600),
answer each one in that chat, and call receive again after every answer, until I say stop.
```

Approve the connection in "My Agent", and accept the request in the app if it asks. On the card of the agent's first answer, tap `all`: its later answers to you need no approval.

## Safety

- The agent asks in "My Agent" before it connects, sends or leaves; you approve or reject.
- `all` approves every message to one chat; `/revoke` ends it.
- Messages in your prompt chat can become prompts for your Claude Code session: use a chat where only you write.
- The agent runs on your computer and has no address in POPOPX Network, so nobody can contact it first.

## Only Claude Code, for now

The agent is tested with Claude Code. Tell us which other apps and models you want to use in [an issue](https://github.com/popopx-chat/popopx-chat/issues), or contribute.

## Reference

Approval modes, owners, several agents, other MCP hosts, recovery and all options: [REFERENCE.md](https://github.com/popopx-chat/popopx-chat/blob/master/packages/popopx-chat-mcp/REFERENCE.md).

## Own a part of POPOPX

Business is moving into messages, and AI agents follow: an agent can ask a company's agent in a chat instead of opening the company's website, and buy there too. These chats hold plans, purchases and accounts, so with AI everyone feels the need for private and secure communication.

POPOPX Chat, the company that builds POPOPX Network, is raising a community round on Wefunder: [wefunder.com/popopx.chat](https://wefunder.com/popopx.chat?utm_source=mcp)

import {readFileSync, existsSync} from "fs"
import {PopopxChatClient} from "./popopx-chat-client.js"

interface Config {
  port: number
  stateFile: string
}

function parseConfig(args: string[]): Config {
  const config: Config = {
    port: 5225,
    stateFile: "./support-bot-state.json"
  }

  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--port" && args[i + 1]) {
      config.port = parseInt(args[i + 1], 10)
      i++
    } else if (args[i] === "--state" && args[i + 1]) {
      config.stateFile = args[i + 1]
      i++
    }
  }

  return config
}

interface BotState {
  lastContactId?: number
  messageCount: number
}

function readState(path: string): BotState {
  if (!existsSync(path)) return {messageCount: 0}
  try { return JSON.parse(readFileSync(path, "utf-8")) } catch { return {messageCount: 0} }
}

function writeState(path: string, state: BotState): void {
  const {writeFileSync} = require("fs")
  writeFileSync(path, JSON.stringify(state, null, 2))
}

async function main(): Promise<void> {
  const config = parseConfig(process.argv.slice(2))
  console.log("[SUPPORT-BOT] Starting with config:", config)

  const state = readState(config.stateFile)
  const client = new PopopxChatClient(config.port)

  client.onEvent(async (eventType, eventData) => {
    console.log(`[EVENT] ${eventType}:`, JSON.stringify(eventData).substring(0, 200))

    if (eventType === "contactConnected") {
      console.log("[SUPPORT-BOT] Contact connected:", eventData.contact?.profile?.displayName)
      const contactId = eventData.contact?.contactId
      if (contactId) {
        await client.sendMessage(
          `@${contactId}`,
          "Hello! This is POPOPX support bot. How can I help you?"
        )
      }
    }

    if (eventType === "newChatItems") {
      const items = eventData.chatItems || []
      for (const item of items) {
        if (item.content?.type === "rcvMsgContent") {
          const msg = item.content.msgContent
          if (msg?.type === "text") {
            console.log(`[MESSAGE] ${item.contact?.profile?.displayName}: ${msg.text}`)
            state.messageCount++
            writeState(config.stateFile, state)

            // Simple auto-reply
            const contactId = item.contact?.contactId
            if (contactId && msg.text) {
              let reply = "Thanks for your message. Our team will respond soon."

              if (msg.text.toLowerCase().includes("help")) {
                reply = "You can ask us about:\n- POPOPX features\n- Privacy & security\n- Getting started"
              } else if (msg.text.toLowerCase().includes("pricing")) {
                reply = "POPOPX is free and open source. Visit popopx.chat for more info."
              }

              await client.sendMessage(`@${contactId}`, reply)
            }
          }
        }
      }
    }
  })

  try {
    await client.connect()
    await client.initialize()
    console.log("[SUPPORT-BOT] Ready and listening for messages")
    console.log("[SUPPORT-BOT] Press Ctrl+C to stop")
  } catch (err) {
    console.error("[SUPPORT-BOT] Failed to start:", err)
    process.exit(1)
  }

  process.on("SIGINT", () => {
    console.log("\n[SUPPORT-BOT] Shutting down...")
    client.disconnect()
    process.exit(0)
  })
}

main().catch(err => {
  console.error("[FATAL]", err)
  process.exit(1)
})

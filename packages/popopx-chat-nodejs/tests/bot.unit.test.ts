import {ChatEvent, T} from "@popopx-chat/types"
import * as api from "../src/api"
import {run, subscribeChatItems} from "../src/bot"

type Handler = (evt: ChatEvent) => Promise<void>

function fakeBot(): {bot: api.ChatApi, deliver: (items: T.AChatItem[]) => Promise<void>} {
  let handler: Handler | undefined
  const bot = {on: (_event: string, h: Handler) => { handler = h }} as unknown as api.ChatApi
  const deliver = (chatItems: T.AChatItem[]) => handler!({type: "newChatItems", chatItems} as unknown as ChatEvent)
  return {bot, deliver}
}

function item(type: "rcvMsgContent" | "sndMsgContent", text: string): T.AChatItem {
  return {chatItem: {content: {type, msgContent: {type: "text", text}}}} as unknown as T.AChatItem
}

describe("subscribeChatItems", () => {
  it("sends a known command only to its handler", async () => {
    const {bot, deliver} = fakeBot()
    const calls: string[] = []
    subscribeChatItems(bot, async () => { calls.push("message") }, {help: async () => { calls.push("help") }})
    await deliver([item("rcvMsgContent", "/help")])
    expect(calls).toEqual(["help"])
  })

  it("sends an unknown command to the fallback handler", async () => {
    const {bot, deliver} = fakeBot()
    const calls: string[] = []
    subscribeChatItems(bot, async () => { calls.push("message") }, {"": async (_ci, cmd) => { calls.push(`fallback:${cmd.keyword}`) }})
    await deliver([item("rcvMsgContent", "/unknown")])
    expect(calls).toEqual(["fallback:unknown"])
  })

  it("sends unhandled commands and text to onMessage", async () => {
    const {bot, deliver} = fakeBot()
    const calls: string[] = []
    subscribeChatItems(bot, async (_ci, content) => { calls.push(`message:${(content as T.MsgContent & {text: string}).text}`) }, {help: async () => { calls.push("help") }})
    await deliver([item("rcvMsgContent", "/unknown"), item("rcvMsgContent", "hello")])
    expect(calls).toEqual(["message:/unknown", "message:hello"])
  })

  it("passes the chat api to handlers", async () => {
    const {bot, deliver} = fakeBot()
    const chats: api.ChatApi[] = []
    subscribeChatItems(bot, async (_ci, _content, chat) => { chats.push(chat) }, {help: async (_ci, _cmd, chat) => { chats.push(chat) }})
    await deliver([item("rcvMsgContent", "/help"), item("rcvMsgContent", "hello")])
    expect(chats).toEqual([bot, bot])
  })

  it("ignores sent items", async () => {
    const {bot, deliver} = fakeBot()
    const calls: string[] = []
    subscribeChatItems(bot, async () => { calls.push("message") }, {help: async () => { calls.push("help") }})
    await deliver([item("sndMsgContent", "/help"), item("sndMsgContent", "hello")])
    expect(calls).toEqual([])
  })
})

describe("run", () => {
  const address = {
    connLinkContact: {connFullLink: "full", connShortLink: "short"},
    addressSettings: {businessAddress: false, autoAccept: {acceptIncognito: false}},
  } as unknown as T.UserContactLink

  function fakeChat(contactDomain?: T.PopopxDomainClaim) {
    const user = {userId: 1, profile: {displayName: "Old", fullName: "", contactDomain}} as unknown as T.User
    const chat = {
      on: jest.fn(),
      apiGetActiveUser: jest.fn().mockResolvedValue(user),
      startChat: jest.fn(),
      apiGetUserAddress: jest.fn().mockResolvedValue(address),
      apiSetAddressSettings: jest.fn(),
      apiSetUserDomain: jest.fn(async (_userId: number, domain?: string) => ({...user, profile: {...user.profile, contactDomain: domain && {domain}}})),
      apiUpdateProfile: jest.fn().mockResolvedValue({updateSuccesses: 0, updateFailures: 0}),
    }
    jest.spyOn(api.ChatApi, "init").mockResolvedValue(chat as unknown as api.ChatApi)
    return chat
  }

  const runBot = (popopxDomain?: string | null, options = {}) =>
    run({profile: {displayName: "Calculator", fullName: ""}, popopxDomain, dbOpts: {type: "sqlite", filePrefix: "unused"}, options})

  const updatedProfile = (chat: ReturnType<typeof fakeChat>) => chat.apiUpdateProfile.mock.calls[0][1]

  beforeEach(() => jest.spyOn(console, "log").mockImplementation(() => {}))
  afterEach(() => jest.restoreAllMocks())

  it("sets the configured POPOPX name", async () => {
    const chat = fakeChat()
    await runBot("Calc.popopx")
    expect(chat.apiSetUserDomain).toHaveBeenCalledWith(1, "calc.popopx")
    expect(updatedProfile(chat).contactDomain).toEqual({domain: "calc.popopx"})
  })

  it("removes the POPOPX name set to null", async () => {
    const chat = fakeChat({domain: "calc.popopx"})
    await runBot(null)
    expect(chat.apiSetUserDomain).toHaveBeenCalledWith(1, undefined)
    expect(updatedProfile(chat).contactDomain).toBeUndefined()
  })

  it("keeps the stored POPOPX name when it is not configured", async () => {
    const chat = fakeChat({domain: "calc.popopx"})
    await runBot()
    expect(chat.apiSetUserDomain).not.toHaveBeenCalled()
    expect(updatedProfile(chat).contactDomain).toEqual({domain: "calc.popopx"})
  })

  it("keeps the POPOPX name when updating the profile", async () => {
    const chat = fakeChat({domain: "calc.popopx", proof: {presHeader: "header", signature: "signature"}})
    await runBot("calc.popopx")
    expect(chat.apiSetUserDomain).not.toHaveBeenCalled()
    expect(updatedProfile(chat).displayName).toBe("Calculator")
    expect(updatedProfile(chat).contactDomain).toEqual({domain: "calc.popopx"})
  })

  it("continues when the POPOPX name cannot be set", async () => {
    const chat = fakeChat()
    chat.apiSetUserDomain.mockRejectedValue(new Error("popopxDomainNotReady"))
    await expect(runBot("calc.popopx")).resolves.toBeDefined()
    expect(updatedProfile(chat).contactDomain).toBeUndefined()
  })

  it("does not change the POPOPX name without updateAddress", async () => {
    const chat = fakeChat()
    await runBot("calc.popopx", {updateAddress: false})
    expect(chat.apiSetUserDomain).not.toHaveBeenCalled()
  })
})

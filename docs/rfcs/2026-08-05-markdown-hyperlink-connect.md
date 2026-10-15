# Connecting via a POPOPX link written as a markdown hyperlink

## Problem

Pasting a short POPOPX link written as a markdown hyperlink — `[label](https://smp6.popopx.im/a#...)` — into the chat list search, the new chat sheet search, or "Tap to paste link" fails with "Invalid connection link" instead of connecting.

## Cause

`markdownP` parses such a link into a single fragment whose `format` is `PopopxLink` but whose `text` is the whole markdown source:

```
[{"format":{"type":"popopxLink","showText":"label","linkType":"contact",
  "popopxUri":"popopx:/a#...?h=smp6.popopx.im","smpHosts":["smp6.popopx.im"]},
  "text":"[label](https://smp6.popopx.im/a#...)"}]
```

`strConnectTarget` returns that `text` as the string to connect with. For a bare link `text` is the link, so it works; for a hyperlink it is `[label](link)`, which the core rejects as `InvalidConnReq`.

## Design

Use `popopxUri` — the link the parser already resolved — when the fragment came from the hyperlink parser, and keep using `text` otherwise:

```
text = if showText != null then popopxUri else text
```

`showText` is an exact discriminator, not a heuristic: `popopxUriFormat` is called with `Just t` only from `sowLinkP` (the hyperlink parser) and with `Nothing` from `wordMD` (bare link). Gating on it leaves every bare-link path unchanged.

This also matches how the chat item renderer already resolves the same format — `TextItemView.kt` takes `popopxUri`, never the fragment `text`, when `showText` is set. `strConnectTarget` was the outlier.

## Scope

Short links only. `sowLinkP` rejects a full link inside a hyperlink (`fail "full POPOPX link in hyperlink"`), so `[label](full-link)` yields no formatting at all and never reaches this code — it stays treated as search text, as before. Bare full links are unaffected.

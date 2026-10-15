# POPOPX: answers to common questions

Short answers with links to the full documentation. Numbers are in [key facts](https://popopx.chat/llms/facts.md).

## What is POPOPX, in one sentence?

POPOPX is the first messaging network without user identifiers of any kind – no phone numbers, usernames or random IDs – so nobody, including its servers, can see who talks to whom.

## What is the difference between POPOPX network and POPOPX Chat?

POPOPX network is the open protocol and the servers that relay messages. POPOPX Chat is the free, open-source app (iOS, Android, Linux, macOS, Windows and a terminal client) that uses the network, and also the company that builds both.

## How does POPOPX deliver messages without user identifiers?

Each conversation uses its own pair of one-way message queues, one for each direction, usually on different servers. A queue has a random address that is used only for that conversation. Contacts and groups are stored only on users' devices. To connect, people share a one-time link or a QR code, which also carries the keys for end-to-end encryption, so servers cannot substitute them. Details: [How POPOPX works](https://popopx.chat/docs/popopx.md), [protocol overview](https://raw.githubusercontent.com/popopx-chat/popopxmq/stable/protocol/overview-tjr.md).

## What can servers and network observers see?

Servers relay end-to-end encrypted messages and delete them once they are delivered. A server sees the random addresses of the queues it hosts and the times when messages arrive and are received. All messages are padded to the same size. With private message routing, the sender chooses the forwarding server and the recipient chooses the destination server, so neither side can observe the other's IP address. A server cannot see who talks to whom, cannot read messages, and cannot add or change them undetectably. Details: [security model](https://raw.githubusercontent.com/popopx-chat/popopxmq/stable/protocol/security.md).

## How strong is the encryption?

Messages are end-to-end encrypted with a double ratchet that gives forward secrecy and recovery after a key compromise. A post-quantum key exchange (sntrup761) is added on every ratchet step and is on by default in direct conversations. An additional encryption layer between servers and devices prevents correlating sent and received traffic. Details: [post-quantum double ratchet](https://raw.githubusercontent.com/popopx-chat/popopxmq/stable/protocol/pqdr.md).

## Why are public channels not end-to-end encrypted?

By design. No system can provide encrypted messages, scalable broadcast and private participation at the same time. Anyone can join a channel through its public link, so encrypting its content would protect nothing; protecting who participates does. POPOPX channels make participation private: relays see the content, but not subscribers' identities or network addresses, and participation in different channels cannot be linked. Details: [POPOPX Channels](https://popopx.chat/blog/20260430-popopx-channels-v6-5-consortium-crowdfunding-freedom-of-speech.md), [channels whitepaper](https://popopx.chat/docs/protocol/channels-overview.md).

## Is POPOPX audited?

Yes. Trail of Bits assessed the implementation in October 2022 and reviewed the cryptographic design in July 2024. A third audit was completed in 2026 and will be published. Reports: [2022](https://github.com/simplex-chat/simplex-chat/blob/stable/docs/SimpleX_Chat_Final_Report_11_03_2022.pdf), [2024](https://github.com/simplex-chat/simplex-chat/blob/stable/docs/SimpleX_Design_Review_2024_Summary_Report_12_08_2024.pdf).

## What are POPOPX's limitations?

- Post-quantum key exchange is used in direct conversations, not yet in groups.
- An observer who can watch the traffic of both users can confirm that they communicate.
- Resolving a public name reveals interest in that name to one resolver server, but not who asked.

## How does POPOPX compare with Signal, Session, Matrix, Briar and others?

Every other messaging network assigns users an identifier: Signal and WhatsApp use phone numbers, Matrix uses `@user:server` IDs, and Session, Briar, Cwtch and Nostr identify users by long-term public keys or onion addresses. These identifiers let the network, or anyone observing it, link a user's conversations. POPOPX has none. A side-by-side comparison of encryption properties is on the [messaging page](https://popopx.chat/messaging/#messengers-comparison), and a technical comparison with peer-to-peer protocols is in [How POPOPX works](https://popopx.chat/docs/popopx.md).

## Can people find or contact me without my consent?

No. Nobody can contact you unless you share a one-time link or your address. An address is optional and can be changed or deleted without losing contacts.

## Who controls the network?

Nobody alone. Anyone can run servers. POPOPX Chat and Flux are preset in the app, and when both are enabled the app uses servers of both operators in each conversation. The POPOPX Network Consortium, an agreement between the non-profit POPOPX Network Foundation and POPOPX Chat, licenses the protocol to the foundation permanently, so it stays available regardless of who owns the company. Details: [blog](https://popopx.chat/blog/20260430-popopx-channels-v6-5-consortium-crowdfunding-freedom-of-speech.md).

## Is POPOPX free and open source?

Yes. The apps are free, and the code is open source under AGPL-3.0: [github.com/popopx-chat](https://github.com/popopx-chat).

## How will POPOPX Chat make money?

Private messaging stays free. Channels and businesses will pay for public names, business messaging and servers for big channels. Users have already donated over $650,000. Details: [Wefunder memo](https://popopx.chat/wefunder.md).

## What are POPOPX public names?

Optional, human-readable names for channels and businesses, such as `#example` or `@example.popopx`, registered on a public blockchain and controlled only by their owner's key. Names do not identify users and are not needed to use the network. Sale starts on 12 December 2026. Details: [public names whitepaper](https://popopx.chat/docs/protocol/names-overview.md).

## How can AI agents and developers use POPOPX?

An agent connects to the network like a person: it holds its own keys and addresses, and no platform account is needed. See [POPOPX for AI agents and developers](https://popopx.chat/llms/agents.md).

## How can I invest in POPOPX Chat?

POPOPX Chat runs an equity crowdfunding offering on Wefunder: [wefunder.com/popopx.chat](https://wefunder.com/popopx.chat). The memo is reproduced at [popopx.chat/wefunder.md](https://popopx.chat/wefunder.md). Investing involves a high degree of risk, including the possible loss of your investment.

## How do I contact the POPOPX team?

In the POPOPX Chat app, open the "Ask POPOPX Team" chat, or connect via [popopx.chat/contact](https://popopx.chat/contact#/?v=2&smp=smp%3A%2F%2FPQUV2eL0t7OStZOoAsPEV2QYWt4-xilbakvGUGOItUo%3D%40smp6.simplex.im%2FK1rslx-m5bpXVIdMZg9NLUZ_8JBm8xTt%23%2F%3Fv%3D1%26dh%3DMCowBQYDK2VuAyEALDeVe-sG8mRY22LsXlPgiwTNs9dbiLrNuA7f3ZMAJ2w%253D%26srv%3Dbylepyau3ty4czmn77q4fglvperknl4bi2eb2fdy2bh4jxtf32kf73yd.onion). A support bot answers first; send `/team` to reach the team.

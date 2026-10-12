//
//  ChatViewBuilders.swift
//  POPOPX
//
//  Extracted from ChatView.swift
//  Helper view builders used by ChatView (reaction context menu, profile helpers).
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// Spec: spec/client/chat-view.md#ReactionContextMenu
struct ReactionContextMenu: View {
    @EnvironmentObject var m: ChatModel
    let groupInfo: GroupInfo
    var itemId: Int64
    var reactionCount: CIReactionCount
    @Binding var selectedMember: GMember?
    var profileRadius: CGFloat
    @State private var memberReactions: [MemberReaction] = []

    var body: some View {
        groupMemberReactionList()
            .task {
                await loadChatItemReaction()
            }
        .popopxBranded()
    }

    @ViewBuilder private func groupMemberReactionList() -> some View {
        if memberReactions.isEmpty {
            ForEach(Array(repeating: 0, count: reactionCount.totalReacted), id: \.self) { _ in
                textSpace
            }
        } else {
            ForEach(memberReactions, id: \.groupMember.groupMemberId) { mr in
                let mem = mr.groupMember
                let userMember = mem.groupMemberId == groupInfo.membership.groupMemberId
                Button {
                    if let member = m.getGroupMember(mem.groupMemberId) {
                        selectedMember = member
                    } else {
                        let member = GMember.init(mem)
                        m.groupMembers.append(member)
                        m.groupMembersIndexes[member.groupMemberId] = m.groupMembers.count - 1
                        selectedMember = member
                    }
                } label: {
                    profileMenuItem(Text(mem.displayName), mem.image, radius: profileRadius)
                }
                .disabled(userMember)
            }
        }
    }

    private func loadChatItemReaction() async {
        do {
            let memberReactions = try await apiGetReactionMembers(
                groupId: groupInfo.groupId,
                itemId: itemId,
                reaction: reactionCount.reaction
            )
            await MainActor.run {
                self.memberReactions = memberReactions
            }
        } catch let error {
            logger.error("apiGetReactionMembers error: \(responseError(error))")
        }
    }
}

func profileMenuItem(_ nameText: Text, _ image: String?, radius: CGFloat) -> some View {
    HStack {
        nameText
        if let image, let img = imageFromBase64(image) {
            Image(uiImage: maskToCustomShape(img, size: 30, radius: radius))
        } else {
            Image(systemName: "person.crop.circle")
        }
    }
}

func maskToCustomShape(_ image: UIImage, size: CGFloat, radius: CGFloat) -> UIImage {
    let path = Path { path in
        if radius >= 50 {
            path.addEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
        } else if radius <= 0 {
            path.addRect(CGRect(x: 0, y: 0, width: size, height: size))
        } else {
            let cornerRadius = size * CGFloat(radius) / 100
            path.addRoundedRect(
                in: CGRect(x: 0, y: 0, width: size, height: size),
                cornerSize: CGSize(width: cornerRadius, height: cornerRadius),
                style: .continuous
            )
        }
    }

    return UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { context in
        context.cgContext.addPath(path.cgPath)
        context.cgContext.clip()
        let scale = size / max(image.size.width, image.size.height)
        let imageSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let imageOrigin = CGPoint(
            x: (size - imageSize.width) / 2,
            y: (size - imageSize.height) / 2
        )
        image.draw(in: CGRect(origin: imageOrigin, size: imageSize))
    }
}

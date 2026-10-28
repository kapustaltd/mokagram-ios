import Foundation
import Postbox
import SwiftSignalKit

/// Desktop's `Mokagram::Bot::Ask` path (`RefreshPage`): inline queries `badges:N` to `@mokagent`, 44
/// holders per page. A result with id `e` carries the shared icon in its title; ids `b<userId>` are holders.
private let mokaBadgesPageSize = 44
private let mokaBadgesMaxPages = 200

private struct MokaBadgesAccumulator {
    var users: [Int64] = []
    var icon: Int64?
}

func _internal_mokaBadgesViaBot(account: Account) -> Signal<Data?, NoError> {
    return _internal_resolvePeerByName(account: account, name: "mokagent", referrer: nil)
    |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
        guard case let .result(resolvedPeerId) = result else {
            return .complete()
        }
        guard let peerId = resolvedPeerId else {
            return .single(nil)
        }
        return account.postbox.transaction { transaction -> EnginePeer? in
            return transaction.getPeer(peerId).flatMap(EnginePeer.init)
        }
    }
    |> take(1)
    |> mapToSignal { bot -> Signal<Data?, NoError> in
        guard let bot else {
            return .single(nil)
        }
        let botId = bot.id
        let selfId = account.peerId

        func page(_ index: Int, _ accumulated: MokaBadgesAccumulator) -> Signal<MokaBadgesAccumulator?, NoError> {
            return _internal_requestChatContextResults(account: account, botId: botId, peerId: selfId, query: "badges:\(index)", offset: "")
            |> map { value -> [ChatContextResult]? in
                return value?.results.results
            }
            |> `catch` { _ -> Signal<[ChatContextResult]?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { results -> Signal<MokaBadgesAccumulator?, NoError> in
                guard let results else {
                    return .single(nil)
                }
                var next = accumulated
                var count = 0
                for result in results {
                    if result.id == "e" {
                        if let title = result.title, let value = Int64(title), value > 0 {
                            next.icon = value
                        }
                    } else if result.id.hasPrefix("b") {
                        count += 1
                        if let user = Int64(result.id.dropFirst()), user > 0 {
                            next.users.append(user)
                        }
                    }
                }
                if count >= mokaBadgesPageSize && index < mokaBadgesMaxPages {
                    return page(index + 1, next)
                }
                return .single(next)
            }
        }

        return page(0, MokaBadgesAccumulator())
        |> map { accumulated -> Data? in
            guard let accumulated else {
                return nil
            }
            var object: [String: Any] = ["users": accumulated.users.map { String($0) }]
            if let icon = accumulated.icon {
                object["emoji_id"] = String(icon)
            }
            return try? JSONSerialization.data(withJSONObject: object)
        }
    }
}

public extension TelegramEngine.Messages {
    /// The mokaGram badge holder list as `badges.json`-shaped data, fetched through `@mokagent`; nil on any failure.
    func mokaBadgesViaBot() -> Signal<Data?, NoError> {
        return _internal_mokaBadgesViaBot(account: self.account)
    }
}

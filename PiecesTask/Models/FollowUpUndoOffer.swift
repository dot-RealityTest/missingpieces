import Foundation

struct FollowUpUndoOffer: Sendable, Equatable {
    let id: String
    let title: String
    let sessionName: String

    var message: String { "Follow-up hidden" }
}

//
//  PhoneWatchTransport.swift
//  LoopWatchApp (watchOS)
//
//  WCSession-backed transport for PhoneWatchMessage on the watch side.
//  Mirrors Loop iOS's PhoneWatchTransport — see that file for the parallel
//  implementation; the two must agree on encoding/decoding conventions.
//

import Foundation
import OmniBLE
import WatchConnectivity

public protocol PhoneWatchTransport: AnyObject {
    var isReachable: Bool { get }
    func sendMessage(_ message: PhoneWatchMessage,
                     reply: ((Result<PhoneWatchMessage, Error>) -> Void)?,
                     onError: ((Error) -> Void)?)
    func queueMessage(_ message: PhoneWatchMessage)
    var onIncomingMessage: ((PhoneWatchMessage) -> Void)? { get set }
}

public final class WCSessionPhoneWatchTransport: NSObject, PhoneWatchTransport, WCSessionDelegate {
    public var onIncomingMessage: ((PhoneWatchMessage) -> Void)?

    private let session: WCSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public var isReachable: Bool { session.isReachable }

    public init(session: WCSession = .default) {
        self.session = session
        super.init()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    public func sendMessage(_ message: PhoneWatchMessage,
                            reply: ((Result<PhoneWatchMessage, Error>) -> Void)?,
                            onError: ((Error) -> Void)?) {
        guard session.isReachable else {
            onError?(PhoneWatchTransportError.counterpartNotReachable)
            return
        }
        do {
            let payload = try encoder.encode(message)
            session.sendMessageData(payload) { replyData in
                guard let reply = reply else { return }
                do {
                    let decoded = try self.decoder.decode(PhoneWatchMessage.self, from: replyData)
                    reply(.success(decoded))
                } catch {
                    reply(.failure(error))
                }
            } errorHandler: { err in
                onError?(err)
            }
        } catch {
            onError?(error)
        }
    }

    public func queueMessage(_ message: PhoneWatchMessage) {
        do {
            let payload = try encoder.encode(message)
            session.transferUserInfo(["phoneWatchMessage": payload])
        } catch {
            // Queue failures are non-fatal for fire-and-forget messages.
        }
    }

    // MARK: - WCSessionDelegate (watchOS)

    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    public func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        handleIncoming(data: messageData, replyHandler: replyHandler)
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        guard let data = userInfo["phoneWatchMessage"] as? Data else { return }
        handleIncoming(data: data, replyHandler: nil)
    }

    private func handleIncoming(data: Data, replyHandler: ((Data) -> Void)?) {
        do {
            let message = try decoder.decode(PhoneWatchMessage.self, from: data)
            onIncomingMessage?(message)
            if let replyHandler = replyHandler {
                // Echo the same message back as the default reply. Coordinator-specific
                // handlers may override this behavior by supplying their own reply.
                replyHandler(data)
            }
        } catch {
            if let replyHandler = replyHandler {
                // Reply with empty data on decode failure; sender will observe error.
                replyHandler(Data())
            }
        }
    }
}

public enum PhoneWatchTransportError: Error {
    case counterpartNotReachable
    case invalidReply
}

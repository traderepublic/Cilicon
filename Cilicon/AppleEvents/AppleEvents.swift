// From https://github.com/soffes/spotlight-tools/tree/master/UtilityKit
import Foundation
import CoreServices

public enum AppleEvent {
    case restart
    case shutDown
    case logOut
    case sleep
    case emptyTrash

    private var eventID: AEEventID {
        switch self {
        case .restart:
            return AEEventID(kAERestart)
        case .shutDown:
            return AEEventID(kAEShutDown)
        case .logOut:
            return AEEventID(kAEReallyLogOut)
        case .sleep:
            return AEEventID(kAESleep)
        case .emptyTrash:
            return AEEventID(kAEEmpty)
        }
    }

    public func perform() {
        SendAppleEventToSystemProcess(eventID)
    }
}

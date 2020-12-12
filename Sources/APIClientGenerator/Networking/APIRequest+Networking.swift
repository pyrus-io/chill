import Foundation
import PromiseKit

public extension APIRequest where Self.ResponseType: Decodable {
    func execute(with networking: Networking) -> Promise<ResponseType> {
        return networking.call(self)
    }
}

public extension APIRequest where Self.ResponseType == Void {
    func execute(with networking: Networking) -> Promise<ResponseType> {
        return networking.call(self)
    }
}

public extension Array where Element: APIRequest, Element.ResponseType: Decodable {
    func executeAll(with networking: Networking) -> Promise<[Element.ResponseType]> {
        return when(fulfilled: self.map(networking.call))
    }
}

public extension Array where Element: APIRequest, Element.ResponseType == Void {
    func executeAll(with networking: Networking) -> Promise<[Element.ResponseType]> {
        return when(fulfilled: self.map(networking.call))
    }
}

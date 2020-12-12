import Foundation
import PromiseKit

public extension APIRequest where Self.ResponseBody: Decodable {
    func execute(with networking: Networking) -> Promise<ResponseBody> {
        return networking.call(self)
    }
}

public extension APIRequest where Self.ResponseBody == Void {
    func execute(with networking: Networking) -> Promise<ResponseBody> {
        return networking.call(self)
    }
}

public extension Array where Element: APIRequest, Element.ResponseBody: Decodable {
    func executeAll(with networking: Networking) -> Promise<[Element.ResponseBody]> {
        return when(fulfilled: self.map(networking.call))
    }
}

public extension Array where Element: APIRequest, Element.ResponseBody == Void {
    func executeAll(with networking: Networking) -> Promise<[Element.ResponseBody]> {
        return when(fulfilled: self.map(networking.call))
    }
}

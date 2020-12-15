import Foundation
import Combine

public extension APIRequest where Self.ResponseBody: Decodable {
    func execute(with networking: Networking) -> AnyPublisher<ResponseBody, NetworkingError> {
        return networking.call(self)
    }
}

public extension APIRequest where Self.ResponseBody == Void {
    func execute(with networking: Networking) -> AnyPublisher<ResponseBody, NetworkingError> {
        return networking.call(self)
    }
}

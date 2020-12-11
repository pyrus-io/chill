import Foundation
import PromiseKit

public extension APIRequest where Self.DecodedResponse: Decodable {
    
    func execute(with networking: Networking = .shared) -> Promise<DecodedResponse> {
        return networking.call(self)
    }
    
}

public extension APIRequest where Self.DecodedResponse == Void {
    
    func execute(with networking: Networking = .shared) -> Promise<DecodedResponse> {
        return networking.call(self)
    }
    
}

public extension Array where Element: APIRequest, Element.DecodedResponse: Decodable {
    
    func executeAll(with networking: Networking = .shared) -> Promise<[Element.DecodedResponse]> {
        return when(fulfilled: self.map(networking.call))
    }
    
}

public extension Array where Element: APIRequest, Element.DecodedResponse == Void {
    
    func executeAll(with networking: Networking = .shared) -> Promise<[Element.DecodedResponse]> {
        return when(fulfilled: self.map(networking.call))
    }
    
}

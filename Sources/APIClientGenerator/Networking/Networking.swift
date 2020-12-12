import Foundation
import PromiseKit

public struct NetworkingError: Swift.Error {
    public enum `Type` {
        case badUrl
        case emptyRequestArray
        case failedEncodeRequest
        case emptyHttpResponse
        case noData
        case failedDecodeResponse
        case unsuccessfulStatusCode
        case urlSessionError(Error)
        case unknown
    }
    
    public let type: Type
    public var statusCode: Int?
}

public final class Networking {
    
    public private(set) var urlSession: URLSession
    
    public var baseURLStringProvider: (AnyAPIRequest) -> String
    public var authRefresh: () -> Promise<Void>
    public var authModifier: (inout URLRequest) -> Void
    public var badStatusCodeHandler: (Int) -> Void
    
    public init(
        urlSession: URLSession = .shared,
        baseURLStringProvider: @escaping (AnyAPIRequest) -> String,
        authRefresh: @escaping () -> Promise<Void> = { .value(()) },
        authModifier: @escaping (inout URLRequest) -> Void = { _ in },
        badStatusCodeHandler: @escaping (Int) -> Void = { _ in }
    ) {
        self.baseURLStringProvider = baseURLStringProvider
        self.urlSession = urlSession
        self.authRefresh = authRefresh
        self.authModifier = authModifier
        self.badStatusCodeHandler = badStatusCodeHandler
    }
        
    public func confirmAuthValidIfNeededOrDie<E: APIRequest>(_ request: E) -> Promise<Void> {
        return authRefresh()
    }
    
    public func callAll<E: APIRequest>(
        _ requests: [E]
    ) -> Promise<[E.ResponseType]> where E.ResponseType: Decodable {

        guard let firstRequest = requests.first else {
            return Promise(error: NetworkingError(type: .emptyRequestArray))
        }

        return confirmAuthValidIfNeededOrDie(firstRequest)
            .then { _ in
                when(fulfilled: requests.map(self.call))
            }
    }
    
    public func call<E: APIRequest>(
        _ request: E
    ) -> Promise<E.ResponseType> where E.ResponseType: Decodable {
        
        return confirmAuthValidIfNeededOrDie(request)
            .then { _ -> Promise<E.ResponseType> in
                let urlRequest: URLRequest
                do {
                    urlRequest = try self.buildUrlRequest(request)
                } catch {
                    return Promise(error: error)
                }
                
                return Promise { (resolver) in
                    let task = self.urlSession.dataTask(with: urlRequest, completionHandler: self.handleDecodableResponse(completion: { (result: Swift.Result<E.ResponseType, NetworkingError>) in
                        switch result {
                        case .success(let data):
                            resolver.fulfill(data)
                        case .failure(let error):
                            resolver.reject(error)
                        }
                    }))
                    task.resume()
                }
        }
        
    }
    
    public func call<E: APIRequest>(
        _ request: E
    ) -> Promise<Void> {
        let urlRequest: URLRequest
        do {
            urlRequest = try buildUrlRequest(request)
        } catch {
            return Promise(error: error)
        }
        
        return Promise { (resolver) in
            let task = self.urlSession.dataTask(with: urlRequest, completionHandler: confirmNoErrorResponse(completion: { (result) in
                switch result {
                case .success(let data):
                    resolver.fulfill(data)
                case .failure(let error):
                    resolver.reject(error)
                }
            }))
            task.resume()
        }
    }
    
}

extension Networking {
    
    private func buildUrlRequest<E: APIRequest>(_ request: E) throws -> URLRequest {
        
        guard let url = URL(string: baseURLStringProvider(request) + request.endpoint) else {
            throw NetworkingError(type: .badUrl)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = E.method.rawValue
        urlRequest.allHTTPHeaderFields = [:]
        
        if E.requiresAuth {
            self.authModifier(&urlRequest)
        }

        do {
            urlRequest.allHTTPHeaderFields?["Content-Type"] = try request.getContentType()
            urlRequest.allHTTPHeaderFields?.merge(request.additionalHeaders, uniquingKeysWith: { $1 })
            if let body = try request.getBody() {
                urlRequest.httpBody = body
            }
        } catch {
            throw NetworkingError(type: .failedEncodeRequest)
        }

        return urlRequest
    }

    private func handleDecodableResponse<T: Decodable>(completion: @escaping (Swift.Result<T, NetworkingError>) -> Void) -> (Data?, URLResponse?, Error?) -> Void {
        return { data, response, error in
            if let e = error {
                completion(.failure(.init(type: .urlSessionError(e))))
            }
            guard let response = response as? HTTPURLResponse else {
                completion(.failure(.init(type: (.emptyHttpResponse))))
                return
            }
            
            guard let data = data else {
                completion(.failure(.init(type: .noData)))
                return
            }
                    
            guard response.statusCode >= 200 && response.statusCode < 300 else {
                completion(.failure(.init(type: .unsuccessfulStatusCode, statusCode: response.statusCode)))
                self.handleBadStatusCodeIfNeeded(statusCode: response.statusCode)
                return
            }
            
            let results: T
            do {
                results = try self.decodeResponse(data: data, with: T.self)
            } catch {
                completion(.failure(.init(type: .failedDecodeResponse)))
                return
            }
            
            completion(.success(results))
        }
    }

    private func confirmNoErrorResponse(completion: @escaping (Swift.Result<Void, NetworkingError>) -> Void) -> (Data?, URLResponse?, Error?) -> Void {
        return { data, response, error in
            if let e = error {
                completion(.failure(.init(type: .urlSessionError(e))))
            }
            guard let response = response as? HTTPURLResponse else {
                completion(.failure(.init(type: .emptyHttpResponse)))
                return
            }
            
            guard response.statusCode >= 200 && response.statusCode < 300 else {
                completion(.failure(.init(type: .unsuccessfulStatusCode, statusCode: response.statusCode)))
                self.handleBadStatusCodeIfNeeded(statusCode: response.statusCode)
                return
            }

            completion(.success(()))
        }
    }

    private func handleBadStatusCodeIfNeeded(statusCode: Int) {
        badStatusCodeHandler(statusCode)
    }

    private func decodeResponse<T: Decodable>(data: Data, with type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let body = try decoder.decode(T.self, from: data)
        return body
    }

}

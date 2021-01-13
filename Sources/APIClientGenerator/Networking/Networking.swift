import Foundation
import Combine

public struct NetworkingError: Swift.Error, Equatable {
    public enum `Type`: Equatable {
        case badUrl
        case emptyRequestArray
        case failedEncodeRequest
        case emptyHttpResponse
        case noData
        case failedDecodeResponse
        case unsuccessfulStatusCode
        case urlSessionError(String)
        case unknown
    }
    
    public let type: Type
    public var statusCode: Int?
}

public final class Networking {
    
    public private(set) var urlSession: URLSession
    
    public var baseURLStringProvider: (AnyAPIRequest) -> String
    public var authRefresh: () -> Future<Void, Error>
    public var authModifier: (inout URLRequest) -> Void
    public var badStatusCodeHandler: (Int) -> Void
    
    public var debug: Bool = false
    
    public init(
        urlSession: URLSession = .shared,
        baseURLStringProvider: @escaping (AnyAPIRequest) -> String,
        authRefresh: @escaping () -> Future<Void, Error> = { Future { $0(.success(())) } },
        authModifier: @escaping (inout URLRequest) -> Void = { _ in },
        badStatusCodeHandler: @escaping (Int) -> Void = { _ in }
    ) {
        self.baseURLStringProvider = baseURLStringProvider
        self.urlSession = urlSession
        self.authRefresh = authRefresh
        self.authModifier = authModifier
        self.badStatusCodeHandler = badStatusCodeHandler
    }
        
    public func confirmAuthValidIfNeededOrDie<E: APIRequest>(_ request: E) -> AnyPublisher<Void, NetworkingError> {
        return authRefresh()
            .mapError { _ in NetworkingError(type: .unknown, statusCode: nil) }
            .eraseToAnyPublisher()
    }
    
    public func call<E: APIRequest>(
        _ request: E
    ) -> AnyPublisher<E.ResponseBody, NetworkingError> where E.ResponseBody: Decodable {
        return confirmAuthValidIfNeededOrDie(request)
            .flatMap { _ -> AnyPublisher<E.ResponseBody, NetworkingError> in
                let urlRequest: URLRequest
                do {
                    urlRequest = try self.buildUrlRequest(request)
                } catch {
                    return Deferred {
                        Future {
                            $0(.failure(
                                NetworkingError(
                                    type: .unknown,
                                    statusCode: nil
                                )))
                        }
                    }
                    .eraseToAnyPublisher()
                }
                
                return Deferred {
                    Future { (resolver) in
                        let task = self.urlSession.dataTask(with: urlRequest, completionHandler: self.handleDecodableResponse(completion: { (result: Swift.Result<E.ResponseBody, NetworkingError>) in
                            switch result {
                            case .success(let data):
                                resolver(.success(data))
                            case .failure(let error):
                                resolver(.failure(error))
                            }
                        }))
                        task.resume()
                    }
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    public func call<E: APIRequest>(
        _ request: E
    ) -> AnyPublisher<Void, NetworkingError> {
        let urlRequest: URLRequest
        do {
            urlRequest = try buildUrlRequest(request)
        } catch {
            return Deferred {
                Future {
                    $0(.failure(
                        NetworkingError(
                            type: .unknown,
                            statusCode: nil
                        )))
                }
            }
            .eraseToAnyPublisher()
        }
        
        return Deferred {
            Future { (resolver) in
                let task = self.urlSession.dataTask(with: urlRequest, completionHandler: self.confirmNoErrorResponse(completion: { (result) in
                    switch result {
                    case .success(let data):
                        resolver(.success(data))
                    case .failure(let error):
                        resolver(.failure(error))
                    }
                }))
                task.resume()
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func upload<E: APIRequest & BinaryEncodable>(_ request: E) -> AnyPublisher<Void, NetworkingError> {
        let urlRequest: URLRequest
        do {
            urlRequest = try buildUrlRequest(request)
        } catch {
            return Deferred {
                Future {
                    $0(.failure(
                        NetworkingError(
                            type: .unknown,
                            statusCode: nil
                        )))
                }
            }
            .eraseToAnyPublisher()
        }
        return Deferred {
            Future { resolver in
                let uploadTask = self.urlSession.uploadTask(with: urlRequest, fromFile: request.fileUrl, completionHandler: self.confirmNoErrorResponse { result in
                    switch result {
                    case .success(let data):
                        resolver(.success(data))
                    case .failure(let e):
                        resolver(.failure(e))
                    }
                })
                uploadTask.resume()
            }
        }
        .eraseToAnyPublisher()
    }
    
}

extension Networking {
    
    private func buildUrlRequest<E: APIRequest>(_ request: E) throws -> URLRequest {
        
        guard let url = URL(string: baseURLStringProvider(request) + request.endpoint) else {
            throw NetworkingError(type: .badUrl)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = E.method.rawValue.uppercased()
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
        
        if debug {
            print(urlRequest.curlString)
        }

        return urlRequest
    }

    private func handleDecodableResponse<T: Decodable>(completion: @escaping (Swift.Result<T, NetworkingError>) -> Void) -> (Data?, URLResponse?, Error?) -> Void {
        return { data, response, error in
            if let e = error {
                completion(.failure(.init(type: .urlSessionError(e.localizedDescription))))
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
                completion(.failure(.init(type: .urlSessionError(e.localizedDescription))))
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

extension URLRequest {
    
    /**
     Returns a cURL command representation of this URL request.
     */
    public var curlString: String {
        guard let url = url else { return "" }
        var baseCommand = "curl \(url.absoluteString)"
        
        if httpMethod == "HEAD" {
            baseCommand += " --head"
        }
        
        var command = [baseCommand]
        
        if let method = httpMethod, method != "GET" && method != "HEAD" {
            command.append("-X \(method)")
        }
        
        if let headers = allHTTPHeaderFields {
            for (key, value) in headers where key != "Cookie" {
                command.append("-H '\(key): \(value)'")
            }
        }
        
        // print small bodies, only 100kb or less
        if let data = httpBody, data.count < 100_000, let body = String(data: data, encoding: .utf8) {
            command.append("-d '\(body)'")
        }
        
        return command.joined(separator: " \\\n\t")
    }
}

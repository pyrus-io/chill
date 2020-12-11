struct Endpoint {
    let name: String
    let method: String
    let path: String
    let parameters: [Property]
    let query: [Property]
    let bodyType: String?
    let responseType: String
    let requiresAuth: Bool
    let tags: [String]?
}

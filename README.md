# struct-vapor-endpoints

Under heavy development. Also needs better name before it's official.

Build your vapor api endpoint as structs. Automatically generate OpenAPISpec documentation and spend less time decoding information from the params/query/body


## Conform to this protocol and the magic happens:
```swift
public protocol APIRoutingEndpoint {
    
    associatedtype Context: APIRoutingContext
    associatedtype Parameters
    associatedtype Query
    associatedtype Body
    associatedtype Response: ResponseEncodable
    
    static var method: APIRoutingHTTPMethod { get }
    static var path: String { get }
    
    static func buildAndRun(from request: Request) throws -> EventLoopFuture<Response>
    static func run(
        context: Context,
        parameters: Parameters,
        query: Query,
        body: Body
    ) throws -> EventLoopFuture<Response>
}
```


### Example with Params and Query
```swift
struct SearchByUsernameEndpoint: APIRoutingEndpoint {
    
    struct SearchParams: Decodable {
        var username: String
    }
    
    struct SearchQuery: Decodable {
        var limit: Int
        var offset: Int
    }
    
    static var method: APIRoutingHTTPMethod = .get
    static var path: String = "/users/search/:username"
    
    static func run(
        context: AuthDatabaseRoutingContext,
        parameters: SearchParams,
        query: SearchQuery,
        body: Void
    ) throws -> EventLoopFuture<[UserViewModel]> {
        // ...
    }
}
```

### Example with body
```swift

struct RegisterEndpoint: APIRoutingEndpoint {
    
    struct RegisterRequest: Decodable {
        var email: String
        var username: String
        var password: String
    }
    
    static var method: APIRoutingHTTPMethod = .post
    static var path: String = "/users/register"
    
    static func run(
        context: AuthDatabaseRoutingContext,
        parameters: Void,
        query: Void,
        body: RegisterRequest
    ) throws -> EventLoopFuture<AuthResponse> {
     // ....
    }
}

```

## Autogen documentation as you do your development by configuring routes like these:

```swift

app.get("api-docs", "json") { (request) -> JSONString in
    let filePath = #file
    var readUrl = URL(fileURLWithPath: filePath)
    readUrl.deleteLastPathComponent()
    do {
        let jsonString = try DocumentationGenerator.generateOpenAPIJSONString(apiDirectoryUrl: readUrl)
        return JSONString(value: jsonString)
    } catch {
        throw error
    }
}

app.get("api-docs") { (request) -> HTML in
    let html = HTML(value:
       """
       <!DOCTYPE html>
       <html>
         <head>
           <title>ReDoc</title>
           <!-- needed for adaptive design -->
           <meta charset="utf-8"/>
           <meta name="viewport" content="width=device-width, initial-scale=1">
           <link href="https://fonts.googleapis.com/css?family=Montserrat:300,400,700|Roboto:300,400,700" rel="stylesheet">
           <!--
           ReDoc doesn't change outer page styles
           -->
           <style>
             body {
               margin: 0;
               padding: 0;
             }
           </style>
         </head>
         <body>
           <redoc spec-url='/api-docs/json'></redoc>
           <script src="https://cdn.jsdelivr.net/npm/redoc@next/bundles/redoc.standalone.js"> </script>
         </body>
       </html>
       """)
    return html
}

```

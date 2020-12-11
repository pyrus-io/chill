internal func openApiTypeToSwiftType(_ type: String, format: String?) -> String {
    switch type {
    case "boolean":
        return "Bool"
    case "integer":
        return "Int"
    case "string":
        if let format = format {
            switch format {
            case "uuid":
                return "UUID"
            case "uri":
                return "URL"
            case "date-time":
                return "Date"
            default:
                break
            }
        }
        return "String"
    case "number":
        return "Double"
    default:
        return type
    }
}

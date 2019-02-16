//
//  AbstractNetworkConstants.swift
//
//
//  Created by Daniele Salvioni on 12/12/2017.
//  Copyright © 2017 Daniele Salvioni. All rights reserved.
//

import Alamofire

public protocol ActivityIndicatorProtocol: class
{
    // mettere i metodi obbligatori che deve avere l'ActivityIndicator
    func showActivityIndicator(_ title: String?)
    func hideActivityIndicator()
    func isActivityIndicatorAlreadyPresent() -> Bool
}

public struct NetworkServiceURL: URLConvertible
{
    let baseURLString: String
    var pathURLString: String?
    
    init(baseURLString: String)
    {
        self.baseURLString = baseURLString
    }
    
    public func asURL() throws -> URL
    {
        let urlString: String
        if let pathURLString = self.pathURLString
        {
            urlString = self.baseURLString + pathURLString
        }
        else
        {
            urlString = self.baseURLString
        }
        
        return try urlString.asURL()
    }
}

public enum NetworkServiceRestOperationType: String
{
    case GET
    case POST
    case PUT
    case DELETE
    
    public func alamofireType() -> HTTPMethod
    {
        switch self
        {
            case .GET:
                return HTTPMethod.get
            case .POST:
                return HTTPMethod.post
            case .PUT:
                return HTTPMethod.put
            case .DELETE:
                return HTTPMethod.delete
        }
    }
}

public enum NetworkServiceAuthType: String
{
    case None
    case Bearer
    case Basic
}

public enum Constants
{
    public enum Network
    {
        public static let BaseUrlKey = "BaseUrl"
        public static let ReachabilityDefaultHost = "www.google.com"
        public static let DefaultValidContentTypeArray = ["application/json"]
        public static let AuthHeaderKey = "Authorization"
        public static let DefaultHeaderDictionary = ["Accept": "application/json"]
        public static let BasicAuthHeaderPreValue = "Basic "
        public static let BearerAuthHeaderPreValue = "Bearer "
    }
}

//
//  AbstractNetworkService.swift
//
//
//  Created by Daniele Salvioni on 12/12/2017.
//  Copyright © 2017 Daniele Salvioni. All rights reserved.
//

import Foundation
import Alamofire
import AlamofireNetworkActivityIndicator
import AlamofireImage
import CodableAlamofire
import SwifterSwift
import SwiftyJSON
import LoggerManager
import Utils

public protocol NetworkServiceDelegate: class
{
    // mettere le chiamate obbigatorie per far compilare
}

public extension NetworkServiceDelegate
{
    // mettere le chiamate opzionali, con implementazione di default vuota, o cmq irrilevante quando poi la subclass le implementerà
    
    func reachabilityStatusChanged(_ status: NetworkReachabilityManager.NetworkReachabilityStatus) {}
}



open class AbstractNetworkService
{
    public weak var delegate: NetworkServiceDelegate?
    
    var baseAddressString: String
    public let dispatchQueue = DispatchQueue.global(qos: .utility)
    
    var reachabilityManager: NetworkReachabilityManager?
    var reachabilityManagerHost: String = Constants.Network.ReachabilityDefaultHost
    var reachabilityEnabled: Bool = false
    
    var defaultHeaders: HTTPHeaders = [:]
    var serviceHeaders: HTTPHeaders = [:]
    var basicAuthHeaderSaved: HTTPHeaders = [:]
    var bearerAuthHeaderSaved: HTTPHeaders = [:]
    
    var logger: LoggerManager = LoggerManager()
    
    public var activityIndicatorIconEnabled: Bool
    {
        get
        {
            return NetworkActivityIndicatorManager.shared.isEnabled
        }
        
        set
        {
            NetworkActivityIndicatorManager.shared.isEnabled = newValue
        }
    }
    
    public var activityIndicatorIconVisible: Bool
    {
        get
        {
            return NetworkActivityIndicatorManager.shared.isNetworkActivityIndicatorVisible
        }
    }
    
    
    
// MARK: - Initializers
    //--------------------------------------------------------------
    public init(baseAddress baseAddressString: String)
    {
        self.baseAddressString = baseAddressString
        
        self.setup()
    }
    
    //--------------------------------------------------------------
    public init(servicePlistName: String, serviceRootKey: String)
    {
        guard let networkDictionary = StorageUtils.loadPlist(name: servicePlistName, rootKey: serviceRootKey) else
        {
            self.baseAddressString = ""
            fatalError("ServiceRootKey not found")
        }
        
        guard let baseUrl = networkDictionary[Constants.Network.BaseUrlKey] as? String else
        {
            self.baseAddressString = ""
            fatalError("BaseUrl not found")
        }
        
        self.baseAddressString = baseUrl
        
        self.setup()
    }
    
    
// MARK: - Configuration
    //--------------------------------------------------------------
    open func setup()
    {
        self.setupLogger()
        self.setupReachability()
        self.setupActivityIndicatorIcon()
        self.setupHeader()
    }
    
    //--------------------------------------------------------------
    fileprivate func setupReachability()
    {
        self.reachabilityManager = NetworkReachabilityManager(host: self.reachabilityManagerHost)
        
        self.reachabilityManager?.listener =
        { status in
            switch status
            {
                case .unknown:
                    self.logger.logDebug(String(describing:status))
                case .notReachable:
                    self.logger.logDebug(String(describing:status))
                case .reachable(let connectionType):
                    self.logger.logDebug(String(describing:status) + String(describing:connectionType))
            }
            self.delegate?.reachabilityStatusChanged(status)
        }
        
        self.enableRechability(false)
    }
    
    //--------------------------------------------------------------
    fileprivate func setupActivityIndicatorIcon()
    {
        NetworkActivityIndicatorManager.shared.startDelay = 1.0
        NetworkActivityIndicatorManager.shared.completionDelay = 0.2
        self.activityIndicatorIconEnabled = true
    }
    
    //--------------------------------------------------------------
    fileprivate func setupHeader()
    {
        self.clearAndAddDefaultHeader()
        self.clearServiceHeader()
        self.clearSavedAllAuth()
    }
    
    //--------------------------------------------------------------
    fileprivate func setupLogger()
    {
        #if DEBUG
            self.logger.logLevel = .debug
        #else
            self.logger.logLevel = .warning
        #endif
    }
    
    
    
// MARK: - Reachability method
    //--------------------------------------------------------------
    public func updateHostForRechability(_ host: String)
    {
        self.reachabilityManagerHost = host
        
        if (self.reachabilityEnabled == true)
        {
            self.reachabilityManager?.stopListening()
            SystemUtils.delay(milliseconds: 500)
            { //[weak self] in
                //guard let strongSelf = self else {return}
                
                self.reachabilityManager?.startListening()
            }
        }
    }

    //--------------------------------------------------------------
    public func enableRechability(_ enable: Bool)
    {
        if (self.reachabilityEnabled != enable)
        {
            self.reachabilityEnabled = enable
            
            if (enable == true)
            {
                self.reachabilityManager?.startListening()
            }
            else
            {
                self.reachabilityManager?.stopListening()
            }
        }
    }
    
    //--------------------------------------------------------------
    fileprivate func isReachable() -> Bool
    {
        if (self.reachabilityEnabled == true)
        {
            if (self.reachabilityManager?.isReachable == true)
            {
                return true
            }
            else
            {
                return false
            }
        }
        else
        {// torno sempre true in caso di reachability disabilitata, così da non sputttanare tutto il giro, cioè che le chiamate partono sempre
            return true
        }
    }
    
    //--------------------------------------------------------------
    fileprivate func manageReachability() -> Bool
    {
        if (self.reachabilityEnabled)
        {
            if (self.isReachable() == false)
            {
                return false
            }
            else
            {
                return true
            }
        }
        else
        {
            return true
        }
    }
    
    
    
// MARK: - ActivityIndicator method
    //--------------------------------------------------------------
    fileprivate func showActivityIndicator(activityIndicator: ActivityIndicatorProtocol?, title: String?)
    {
        activityIndicator?.showActivityIndicator(title)
    }
    
    //--------------------------------------------------------------
    fileprivate func showActivityIndicatorArray(_ activityIndicatorArray: [ActivityIndicatorProtocol]?)
    {
        
    }
    
    //--------------------------------------------------------------
    fileprivate func hideActivityIndicator(_ activityIndicator: ActivityIndicatorProtocol?)
    {
        activityIndicator?.hideActivityIndicator()
    }
    
    //--------------------------------------------------------------
    fileprivate func hideActivityIndicatorArray(_ activityIndicatorArray: [ActivityIndicatorProtocol]?)
    {
        
    }

    
    
// MARK: - Default Header Method
    //--------------------------------------------------------------
    open func addDefaultHeader()
    {
        self.defaultHeaders += Constants.Network.DefaultHeaderDictionary
    }
    
    //--------------------------------------------------------------
    public func clearAndUpdateDefaultHeader(_ header: HTTPHeaders)
    {
        self.defaultHeaders.removeAll()
        self.defaultHeaders += header
    }
    
    //--------------------------------------------------------------
    fileprivate func clearAndAddDefaultHeader()
    {
        self.defaultHeaders.removeAll()
        self.addDefaultHeader()
    }
    
    
    
// MARK: -  Service Header Method
    //--------------------------------------------------------------
    public func addServiceHeader(_ header: HTTPHeaders)
    {
        self.serviceHeaders += header
    }
    
    //--------------------------------------------------------------
    public func removeServiceHeaderWithKey(_ key: String)
    {
        self.serviceHeaders.removeValue(forKey: key)
    }
    
    //--------------------------------------------------------------
    fileprivate func clearServiceHeader()
    {
        self.serviceHeaders.removeAll()
    }
    
    
    
// MARK: -  Authentication Header Method
    //--------------------------------------------------------------
    public func addBasicAuth(username: String, password: String)
    {
        let authHeader: HTTPHeaders = [Constants.Network.AuthHeaderKey : (Constants.Network.BasicAuthHeaderPreValue + "\(username):\(password)".base64Encoded!)]
        self.addServiceHeader(authHeader)
    }
    
    //--------------------------------------------------------------
    fileprivate func addSavedBasicAuth()
    {
        if (!self.basicAuthHeaderSaved.isEmptyOrNil)
        {
            self.addServiceHeader(self.basicAuthHeaderSaved)
            self.logger.logDebug("basicAuthHeaderSaved added")
        }
    }
    
    //--------------------------------------------------------------
    public func saveBasicAuth()
    {
        if let basicAuthValue = self.serviceHeaders[Constants.Network.AuthHeaderKey]
        {
            self.basicAuthHeaderSaved = [Constants.Network.AuthHeaderKey : basicAuthValue]
        }
    }
    
    //--------------------------------------------------------------
    fileprivate func clearSavedBasicAuth()
    {
        self.basicAuthHeaderSaved.removeAll()
    }
    
    //--------------------------------------------------------------
    public func addBearerAuth(token: String)
    {
        let authHeader: HTTPHeaders = [Constants.Network.AuthHeaderKey : (Constants.Network.BearerAuthHeaderPreValue + "\(token)")]
        self.addServiceHeader(authHeader)
    }
    
    //--------------------------------------------------------------
    fileprivate func addSavedBearerAuth()
    {
        if (!self.bearerAuthHeaderSaved.isEmptyOrNil)
        {
            self.addServiceHeader(self.bearerAuthHeaderSaved)
            self.logger.logDebug("bearerAuthHeaderSaved added")
        }
    }
    
    //--------------------------------------------------------------
    public func saveBearerAuth()
    {
        if let bearerAuthValue = self.serviceHeaders[Constants.Network.AuthHeaderKey]
        {
            self.bearerAuthHeaderSaved = [Constants.Network.AuthHeaderKey : bearerAuthValue]
        }
    }
    
    //--------------------------------------------------------------
    fileprivate func clearSavedBearerAuth()
    {
        self.bearerAuthHeaderSaved.removeAll()
    }
    
    //--------------------------------------------------------------
    public func clearAllAuth()
    {
        self.removeServiceHeaderWithKey(Constants.Network.AuthHeaderKey)
    }
    
    //--------------------------------------------------------------
    fileprivate func clearSavedAllAuth()
    {
        self.clearSavedBasicAuth()
        self.clearSavedBearerAuth()
    }
    
    
    
// MARK: - Manage Header Method
    //--------------------------------------------------------------
    fileprivate func manageAdditionalServiceHeaders(_ additionalServiceHeaders: HTTPHeaders)
    {
        self.addServiceHeader(additionalServiceHeaders)
    }
    
    //--------------------------------------------------------------
    fileprivate func manageSavedAuthByType(_ authType: NetworkServiceAuthType)
    {
        switch authType
        {
            case .None:
            // senza autenticazione salvata
                break
            
            case .Basic:
            // autenticazione con Basic, carico l'header salvato nel service
                self.addSavedBasicAuth()
            
            case .Bearer:
            // autenticazione con Bearer, carico l'header salvato nel service
                self.addSavedBearerAuth()
        }
    }
    
    //--------------------------------------------------------------
    fileprivate func manageHeaders() -> HTTPHeaders
    {
        var headers: HTTPHeaders = [:]
        
        // carico i default
        headers += self.defaultHeaders
        
        // carico i service
        headers += self.serviceHeaders
        
        //ritorno il tutto
        return headers
    }
   
    
    
// MARK: - Path/Url Address Method
    //--------------------------------------------------------------
    public func updateBaseAddressUrl(_ baseAddressString: String)
    {
        self.baseAddressString = baseAddressString
    }
    
    //--------------------------------------------------------------
    fileprivate func managePathUrl(_ pathUrl: URLConvertible) -> URLConvertible
    {
        if let pathUrlString = pathUrl as? String
        {// è stringa
            if (pathUrlString.isValidSchemedUrl)
            {// path assoluto -> ritorno la stringa diretta così com'è
                return pathUrlString
            }
            else
            {// path relativo -> alloco un NetworkServiceURL e ci metto pathUrlString come path
                var networkServiceUrl = NetworkServiceURL(baseURLString: self.baseAddressString)
                networkServiceUrl.pathURLString = pathUrlString
                return networkServiceUrl
            }
        }
        else
        {// è URLConvertible -> torno diretto
            return pathUrl
        }
    }
    
    
    
// MARK: - REST Method
    //--------------------------------------------------------------
    fileprivate func performRestOperationWithDecodable<ResponseClass: Decodable>(_ restOperationType: NetworkServiceRestOperationType,
                                                                                 pathUrl: URLConvertible,
                                                                                 parameters: Parameters,
                                                                                 encoding: ParameterEncoding,
                                                                                 savedAuthType: NetworkServiceAuthType,
                                                                                 additionalServiceHeaders: HTTPHeaders = [:],
                                                                                 activityIndicator: ActivityIndicatorProtocol? = nil,
                                                                                 activityIndicatorMessage: String? = nil,
                                                                                 successBlock:@escaping (_ responseObject: ResponseClass) -> Void,
                                                                                 errorBlock:@escaping (_ error: Error, _ validResponse: Bool) -> Void)
    {
        let restConfiguration = self.setupRestOperation(savedAuthType: savedAuthType,
                                                        pathUrl: pathUrl,
                                                        additionalServiceHeaders: additionalServiceHeaders,
                                                        activityIndicator: activityIndicator,
                                                        activityIndicatorMessage: activityIndicatorMessage)
        
        Alamofire.request(restConfiguration.url,
                          method: restOperationType.alamofireType(),
                          parameters:parameters,
                          encoding:encoding,
                          headers:restConfiguration.headers).validate(contentType:Constants.Network.DefaultValidContentTypeArray).responseDecodableObject(queue: self.dispatchQueue,
                                                                                                                                                          keyPath: nil,
                                                                                                                                                          decoder: JSONDecoder(),
                                                                                                                                                          completionHandler:
        { (responseObject: DataResponse<ResponseClass>) in
            self.completionRestOperation(responseObject: responseObject,
                                         activityIndicator: activityIndicator,
                                         successBlock: successBlock,
                                         errorBlock: errorBlock)
        })
    }
    
    //--------------------------------------------------------------
    public func performRestOperation<ResponseMappedClass :AnyObject>(_ restOperationType: NetworkServiceRestOperationType,
                                                                     pathUrl: URLConvertible,
                                                                     parameters: Parameters = [:],
                                                                     encoding: ParameterEncoding = URLEncoding.queryString,
                                                                     savedAuthType: NetworkServiceAuthType,
                                                                     additionalServiceHeaders: HTTPHeaders = [:],
                                                                     activityIndicator: ActivityIndicatorProtocol? = nil,
                                                                     activityIndicatorMessage: String? = nil,
                                                                     successBlock:@escaping (_ responseObject: ResponseMappedClass) -> Void,
                                                                     errorBlock:@escaping (_ error: Error, _ validResponse: Bool) -> Void) where ResponseMappedClass: Decodable
    {
        if self.canDoRestOperation(errorBlock: errorBlock) != true { return }
        
        self.performRestOperationWithDecodable(restOperationType,
                                               pathUrl: pathUrl,
                                               parameters: parameters,
                                               encoding: encoding,
                                               savedAuthType: savedAuthType,
                                               activityIndicator: activityIndicator,
                                               activityIndicatorMessage: activityIndicatorMessage,
                                               successBlock: successBlock,
                                               errorBlock: errorBlock)
    }
    
    //--------------------------------------------------------------
    public func performRestOperation<ResponseMappedClass :AnyObject>(_ restOperationType: NetworkServiceRestOperationType,
                                                                     pathUrl: URLConvertible,
                                                                     parameters: Parameters = [:],
                                                                     encoding: ParameterEncoding = URLEncoding.queryString,
                                                                     savedAuthType: NetworkServiceAuthType,
                                                                     additionalServiceHeaders: HTTPHeaders = [:],
                                                                     activityIndicator: ActivityIndicatorProtocol? = nil,
                                                                     activityIndicatorMessage: String? = nil,
                                                                     successBlock:@escaping (_ responseObject: ResponseMappedClass) -> Void,
                                                                     errorBlock:@escaping (_ error: Error, _ validResponse: Bool) -> Void)
    {
        // se viene chiamata questa vuol dire che c'è un errore grave: assert
        fatalError("RestOperation not allowed with This Object Type: \(ResponseMappedClass.self)")
    }
    
    //--------------------------------------------------------------
    public func canDoRestOperation(errorBlock:@escaping (_ error: Error, _ validResponse: Bool) -> Void) -> Bool
    {
        // test di reachability
        if (self.manageReachability() == false)
        {
            // test fallito: non eseguo la chiamata e restituisco errore
            let error = SystemUtils.createNSError(message: "REACHABILITY_RESULT_NETWORK_UNREACHABLE".localized())
            errorBlock(error, false) // false perchè il flag indica se è un errore della risposta che è valida (true), o se è successo qualcosa d'altro (false)
            return false
        }
        
        return true
    }
    
    //--------------------------------------------------------------
    public func setupRestOperation(savedAuthType: NetworkServiceAuthType,
                                   pathUrl: URLConvertible,
                                   additionalServiceHeaders: HTTPHeaders,
                                   activityIndicator: ActivityIndicatorProtocol? = nil,
                                   activityIndicatorMessage: String? = nil) -> (headers: HTTPHeaders, url: URLConvertible)
    {
        // resetto i service header
        self.clearServiceHeader()
        
        // metto gli header di auth salvati, se richiesti, nei service
        self.manageSavedAuthByType(savedAuthType)
        
        // metto gli eventuali headers addizionali
        self.manageAdditionalServiceHeaders(additionalServiceHeaders)
        
        // genero gli headers con default + service, se presenti
        let headers = self.manageHeaders()
        
        // genero l'indirizzo
        let url = self.managePathUrl(pathUrl)
        
        // faccio partire l'activity, se c'è
        self.showActivityIndicator(activityIndicator: activityIndicator, title: activityIndicatorMessage)
        
        return (headers: headers, url: url)
    }
    
    //--------------------------------------------------------------
    public func completionRestOperation<ResponseClass>(responseObject:DataResponse<ResponseClass>,
                                                       activityIndicator: ActivityIndicatorProtocol? = nil,
                                                       successBlock:@escaping (_ responseObject: ResponseClass) -> Void,
                                                       errorBlock:@escaping (_ error: Error, _ validResponse: Bool) -> Void)
    {
        SystemUtils.delay(milliseconds: 0.0, completion:
        {
            // TODO: aggiungere una impostazione globale, per abilitare o meno il log di rete
                
            // loggo
            self.logRestService(responseObject)
                
            guard let _ = responseObject.result.value else
            {
                self.logger.logDebug("invalid response")
                let error = SystemUtils.createNSError(message: "Error conversion")
                errorBlock(error, false)
                self.hideActivityIndicator(activityIndicator)
                return
            }

            if (responseObject.result.isSuccess)
            {// success
                let response: ResponseClass = responseObject.result.value!
                successBlock(response)
                
                self.hideActivityIndicator(activityIndicator)
            }
            else
            {// failure
                self.hideActivityIndicator(activityIndicator)
                
                self.logger.logDebug("invalid response")
                guard let error = responseObject.result.error else
                {
                    let error = SystemUtils.createNSError(message: "INTERNAL_ERROR".localized())
                    errorBlock(error, false)
                    return
                }
                
                errorBlock(error, true)
            }
        })
    }
    
    
    
// MARK: - Test related Method
    //--------------------------------------------------------------
    public func performRestOperationForTest(restOperationType: NetworkServiceRestOperationType,
                                            pathUrl: URLConvertible,
                                            serviceBaseName: String,
                                            encoding: ParameterEncoding,
                                            headers: HTTPHeaders,
                                            request: Parameters,
                                            response: Parameters,
                                            successBlock:@escaping (_ responseObject: Dictionary<String, Any>) -> Void,
                                            errorBlock:@escaping (_ error: Error, _ validResponse: Bool) -> Void)
    {
        if self.canDoRestOperation(errorBlock: errorBlock) != true { return }
        
        let restConfiguration = self.setupRestOperation(savedAuthType: NetworkServiceAuthType.None,
                                                        pathUrl: pathUrl,
                                                        additionalServiceHeaders: headers,
                                                        activityIndicator: nil,
                                                        activityIndicatorMessage: nil)
        
        Alamofire.request(restConfiguration.url,
                          method: restOperationType.alamofireType(),
                          parameters:request,
                          encoding:encoding,
                          headers:restConfiguration.headers).validate(contentType:Constants.Network.DefaultValidContentTypeArray).responseJSON
        { responseObject in
                
            switch responseObject.result
            {
                case .success(let value):
                    let json = JSON(value)
                    successBlock(json.dictionaryObject ?? [:])
                
                case .failure(let error):
                    errorBlock(error, true)
            }
        }
    }
    
    
    
// MARK: - Download Method
    //--------------------------------------------------------------
    public func downloadImageAsync(pathUrl: URLConvertible,
                                   successBlock:@escaping (_ image: UIImage) -> Void,
                                   errorBlock:@escaping (_ error: Error, _ validResponse: Bool) -> Void)
    {
        // test di reachability
        if (self.manageReachability() == false)
        {
            // test fallito: non eseguo la chiamata e restituisco errore
            let error = SystemUtils.createNSError(message: "REACHABILITY_RESULT_NETWORK_UNREACHABLE".localized())
            errorBlock(error, false) // false perchè il flag indica se è un errore della risposta che è valida (true), o se è successo qualcosa d'altro (false)
            return
        }
        
        // genero l'indirizzo
        let url = self.managePathUrl(pathUrl)
        
        // lancio il download
        Alamofire.request(url).responseImage
        { responseObject in
            
            SystemUtils.delay(milliseconds: 0.0, completion:
            {
                // TODO: aggiungere una impostazione globale, per abilitare o meno il log di rete
                // loggo
                self.logger.logDebug("""
                    
                    
                    ******************************
                    - Request:
                    \(String(describing: responseObject.request)) // original url request
                    - Response:
                    \(String(describing: responseObject.response)) // http url response
                    - Result:
                    \(String(describing: responseObject.result)) // http url result
                    ******************************
                    
                    """)
                
                guard let _ = responseObject.result.value else
                {
                    self.logger.logDebug("invalid response")
                    let error = SystemUtils.createNSError(message: "Error download image")
                    errorBlock(error, false)
                    
                    return
                }
                
                if (responseObject.result.isSuccess)
                {// successo
                    guard let image = responseObject.result.value else
                    {
                        let error = SystemUtils.createNSError(message: "INTERNAL_ERROR".localized())
                        errorBlock(error, false)
                        return
                    }
                    
                    successBlock(image)
                }
                else
                {
                    self.logger.logDebug("invalid response")
                    
                    guard let error = responseObject.result.error else
                    {
                        let error = SystemUtils.createNSError(message: "INTERNAL_ERROR".localized())
                        errorBlock(error, false)
                        return
                    }
                    
                    errorBlock(error, true)
                }
            })
        }
    }
    
    //--------------------------------------------------------------
    public func setImageAsyncFromMainBundle(name: String, ext: String) -> UIImage?
    {
        let url = Bundle.main.url(forResource: name, withExtension: ext)!
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let image = UIImage(data: data, scale: UIScreen.main.scale) else { return nil }
        
        image.af_inflate()
        
        return image
    }
    
    
    
// MARK: - Utils Method
    //--------------------------------------------------------------
    fileprivate func logRestService<ResponseClass>(_ responseObject: DataResponse<ResponseClass>)
    {
        // preparo le stringhe la loggare
        let serviceUrlDebug = self.cleanForDebug(responseObject.request?.url?.absoluteString)
        let restMethodDebug = self.cleanForDebug(responseObject.request?.httpMethod)
        let requestHeaderDebug = self.cleanForDebug(responseObject.request?.allHTTPHeaderFields?.jsonString(prettify: true))
        let requestParametersQueryStringDebug = self.cleanForDebug(responseObject.request?.url?.queryDictionary?.jsonString(prettify: true))
        let requestParametersBodyDebug = self.cleanForDebug(responseObject.request!.httpBody.map { body in String(data: body, encoding: .utf8) ?? "" })
        let responseHeaderDebug = self.cleanForDebug(responseObject.response?.allHeaderFields.jsonString(prettify: true))
        let responseBodyDebug = self.cleanForDebug(try? JSON(data: responseObject.data ?? Data()).rawString(String.Encoding.utf8, options: JSONSerialization.WritingOptions.prettyPrinted) ?? "")
        
        // loggo
        self.logger.logDebug("""
            
            
            ******************************
            - Service URL:
            \(serviceUrlDebug)
            - Rest Method:
            \(restMethodDebug)
            - Request Header:
            \(requestHeaderDebug)
            - Request Parameters in Querystring:
            \(requestParametersQueryStringDebug)
            - Request Parameters in Body:
            \(requestParametersBodyDebug)
            - Response Header:
            \(responseHeaderDebug)
            - Response Body:
            \(responseBodyDebug)
            ******************************
            
            """)
    }
    
    //--------------------------------------------------------------
    fileprivate func cleanForDebug(_ stringToClean: String?) -> String
    {
        let stringClean = stringToClean?.replacingOccurrences(of: "\\/", with: "/")
        
        return stringClean ?? "<empty>"
    }
}

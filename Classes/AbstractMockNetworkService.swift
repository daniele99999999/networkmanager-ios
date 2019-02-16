//
//  AbstractMockNetworkService.swift
//
//
//  Created by Daniele Salvioni on 12/12/2017.
//  Copyright © 2017 Daniele Salvioni. All rights reserved.
//

import Foundation
import SwifterSwift
import Utils

open class AbstractMockNetworkService
{
    public var enableSuccessMock: Bool
    public var responseDelay: Float
    
    public var bundle: Bundle = Bundle(for: AbstractMockNetworkService.self)
    
    
// MARK: - Initializers
    //--------------------------------------------------------------
    public init(enableSuccessMock: Bool, responseDelay: Float)
    {
        self.enableSuccessMock = enableSuccessMock
        self.responseDelay = responseDelay
        
        self.setup()
    }

    
// MARK: - Configuration
    //--------------------------------------------------------------
    open func setup()
    {
        self.configureBundleForMock()
    }
    
    //--------------------------------------------------------------
    func configureBundleForMock()
    {
        let implementationClass: AnyClass = self.getImplementationClass()
        self.bundle = Bundle(for: implementationClass)
    }

    
// MARK: - Utils Method
    //--------------------------------------------------------------
    open func getImplementationClass() -> AnyClass
    {
        fatalError("This method must be overridden")
    }
    
    //--------------------------------------------------------------
    public func performMockRestOperation<ResponseClass: AnyObject>(activityIndicator: ActivityIndicatorProtocol? = nil,
                                                                   activityIndicatorMessage: String? = nil,
                                                                   restOperationType: NetworkServiceRestOperationType,
                                                                   serviceBaseName: String,
                                                                   successBlock:@escaping (_ responseObject: ResponseClass) -> Void,
                                                                   errorBlock:@escaping (_ error: Error, _ validResponse: Bool) -> Void) where ResponseClass: Decodable
    {
        activityIndicator?.showActivityIndicator(activityIndicatorMessage)
        
        // creo la stringa identificativa del servizio
        let serviceName = "service." + restOperationType.rawValue.lowercased() + "." + serviceBaseName // + "." + self.enableSuccessMock.string
        
        // carico il Json della response, col nome corretto in base al enableSuccessMock
        guard let jsonData: Data = StorageUtils.loadJSON(name: serviceName + ".response", bundle: self.bundle) else
        {
            activityIndicator?.hideActivityIndicator()
            
            errorBlock(SystemUtils.createNSError(message: "Error loading success mock response"), true)
            return
        }
        
        // converto con codable
        guard let jsonObject: ResponseClass = self.objectDecode(jsonData) else
        {
            activityIndicator?.hideActivityIndicator()
            
            errorBlock(SystemUtils.createNSError(message: "Error converting \(ResponseClass.self) object"), true)
            return
        }
    
        // in base a enableSuccessMock, ritorno il blocco corrispondente
        if (self.enableSuccessMock == true)
        {
            SystemUtils.delay(milliseconds: self.responseDelay.double)
            {
                activityIndicator?.hideActivityIndicator()
                
                successBlock(jsonObject)
            }
        }
        else
        {
            SystemUtils.delay(milliseconds: self.responseDelay.double)
            {
                activityIndicator?.hideActivityIndicator()
                
                errorBlock(SystemUtils.createNSError(message: "Error: loaded failure mock response"), true)
            }
        }
    }
    
    //--------------------------------------------------------------
    fileprivate func objectDecode<ResponseClass: Decodable>(_ jsonData: Data) -> ResponseClass?
    {
        // converto con codable
        let jsonObject = try? JSONDecoder().decode(ResponseClass.self, from: jsonData)
        
        return jsonObject
    }
    
    //--------------------------------------------------------------
    public func performMockRestOperation<ResponseClass: AnyObject>(activityIndicator: ActivityIndicatorProtocol? = nil,
                                                                   activityIndicatorMessage: String? = nil,
                                                                   restOperationType: NetworkServiceRestOperationType,
                                                                   serviceBaseName: String,
                                                                   successBlock:@escaping (_ responseObject: ResponseClass) -> Void,
                                                                   errorBlock:@escaping (_ error: Error, _ validResponse: Bool) -> Void)
    {
        // se viene chiamata questa vuol dire che c'è un errore grave: assert
        fatalError("MockRestOperation not allowed with This Object Type: \(ResponseClass.self)")
    }
}

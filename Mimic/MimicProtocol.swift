//
//  MimicProtocol.swift
//  Mimic
//
//  Created by Felipe Ruz on 5/23/19.
//  Copyright © 2019 Felipe Ruz. All rights reserved.
//

class MimicProtocol: URLProtocol {
    static var mimics = [MimicObject]()
    static var registered = false

    class func mimic(_ mimic: MimicObject) -> MimicObject {
        mimics.append(mimic)
        if !registered {
            registered = URLProtocol.registerClass(MimicProtocol.self)
            URLSessionConfiguration.activateMimic()
        }
        return mimic
    }

    class func mimic(for request: URLRequest) -> MimicObject? {
        for mimic in mimics {
            if mimic.request(request) {
                return mimic
            }
        }
        return nil
    }

    class func stopMimic(_ mimic: MimicObject) {
        if let index = mimics.index(of: mimic) {
            mimics.remove(at: index)
        }
    }

    class func stopAllMimics() {
        mimics.removeAll()
        URLProtocol.unregisterClass(MimicProtocol.self)
        URLSessionConfiguration.deactivateMimic()
        registered = false
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard mimic(for: request) != nil else { return false }
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        if let mimic = MimicProtocol.mimic(for: request) {
            DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + mimic.delay) {
                self.responseType(mimic.response(self.request))
            }
        } else {
            let error = NSError(
                domain: NSExceptionName.internalInconsistencyException.rawValue,
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "No Mimic for request"]
            )
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    func responseType(_ responseType: MimicResponseType) {
        switch responseType {
        case let .success(response, content):
            switch content {
            case let .content(data):
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
            case .empty:
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
}

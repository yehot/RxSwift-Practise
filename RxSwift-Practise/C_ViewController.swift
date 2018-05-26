//
//  C_ViewController.swift
//  RxSwift-Practise
//
//  Created by yehot on 2018/5/25.
//  Copyright © 2018年 Xin Hua Zhi Yun. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift

class C_ViewController: UIViewController {

    lazy var bag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        let request = URLRequest.init(url: URL.init(string: "https://github.com/fluidicon.png")!)
        URLSession.shared.sendRequest(request)
            .subscribe(onNext: { (data, response) in
                print(response)
            }, onError: { (error) in
                print(error)
            })
            .disposed(by: bag)
    }
}

extension URLSession {
    /**
     1. 对 URLSession 进行 rx 扩展
     
     2. Observable<> ： 保装可观察的对象
     
     3. Observable.create  入参是 block ，返回值是一个 RxSwift.Observable<Self.E> ，一遍由类型推断得出
     
     */
    public func sendRequest(_ request: URLRequest) -> Observable<(Data, URLResponse)> {
        return Observable.create { observer -> Disposable in
            let task = self.dataTask(with: request, completionHandler: { (data, response, error) in
                if let tData = data, let resp = response{
                    observer.onNext((tData, resp))
                }
                if let err = error {
                    observer.onError(err)
                }
                observer.onCompleted()
            })
            task.resume()
            
            return Disposables.create {
                task.cancel()
            }
        }
    }
    
    // 简化写法： Observable.create 出一个 可观察的（Observable的） string 类型对象
    func test() -> Observable<String> {
        return Observable.create { observer -> Disposable in
            return Disposables.create()
        }
    }
    
}

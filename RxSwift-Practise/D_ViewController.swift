//
//  D_ViewController.swift
//  RxSwift-Practise
//
//  Created by yehot on 2018/5/28.
//  Copyright © 2018年 Xin Hua Zhi Yun. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift

// https://medium.com/@DianQK/%E5%9C%A8%E5%AE%9E%E8%B7%B5%E4%B8%AD%E5%BA%94%E7%94%A8-rxswift-%E5%B9%B6%E5%8F%91-f947f2c316a5
class D_ViewController: UIViewController {

    lazy var bag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

//        objectToRxObservable()
        rxSerialConcurrentDemo()
    }
    
    // MARK: 2. 有序请求 demo
    func rxSerialConcurrentDemo() {
        let array1 = [1, 2, 3, 4, 5, 6, 7, 8]
        Observable.from(array1)
            .map { (num) -> URLRequest in
                let urlStr = "https://httpbin.org/get?foo=" + String(num)
                return URLRequest.init(url: URL.init(string: urlStr)!)
            }
            .map { (request) -> Observable<Data> in // flat map 改为 map
                URLSession.shared.rx.data(request: request)
            }
            .concat()   // 串行
//            .merge(maxConcurrent: 3)    // 控制并发
            .map({ (data) -> [String : Any]? in
                let dict = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
                return dict as? [String : Any]
            })
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { (dict) in
                if let jsonDict = dict {
                    print(jsonDict)
                }
            })
            .disposed(by: bag)
    }

    // MARK: 1. 并发请求 demo （无序）
    func rxConcurrentDemo() {
        let array1 = [1, 2, 3, 4]
        Observable.from(array1)
            .map { (num) -> URLRequest in
                let urlStr = "https://httpbin.org/get?foo=" + String(num)
                return URLRequest.init(url: URL.init(string: urlStr)!)
            }
            .flatMap { (request) -> Observable<Data> in
                 URLSession.shared.rx.data(request: request)
            }
            .map({ (data) -> [String : Any]? in
                let dict = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
                return dict as? [String : Any]
            })
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { (dict) in
                if let jsonDict = dict {
                    print(jsonDict)
                }
            })
            .disposed(by: bag)
    }
    
    // MARK: 将 Native obj 转为 rx Observable
    func objectToRxObservable() {
        // 1.将数组包装为 Variable，转为 Observable
        let array1 = [1, 2, 3, 4]
        let observableArray = Variable(array1)
        
        // 2.订阅 数组
        observableArray.asObservable()
            .subscribe(onNext: { (array) in
                print(array)
            })
            .disposed(by: bag)
        
        // 3.修改数组
        observableArray.value.append(5)
        
        // Variable 不再推荐使用，可换用 BehaviorRelay
        let array2 = BehaviorRelay(value: array1)
        array2.asObservable()
            .subscribe { (arr) in
                
            }
            .disposed(by: bag)
    }
    
    // MARK:  将 array 转换为 流
    func arrayToFlow() {
        let array1 = [1, 2, 3, 4]
        Observable.from(array1)
            .subscribe(onNext: { (num) in
                print(num)
            })
            .disposed(by: bag)
    }

    // flat map 使用
    func testFlatMap() {
        let first = BehaviorSubject(value: "👦🏻")
        let variable = Variable(first)
        
        // rxswift 中，flat map 和 map 的区别：
        //  flatMap 处理的闭包，必须是 ObservableType -> ObservableConvertibleType
        variable.asObservable()
            .flatMap { $0 }
            .subscribe(onNext: { print($0) })
            .disposed(by: bag)
    }
}

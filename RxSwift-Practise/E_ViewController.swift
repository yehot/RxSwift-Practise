//
//  E_ViewController.swift
//  RxSwift-Practise
//
//  Created by yehot on 2018/5/29.
//  Copyright © 2018年 Xin Hua Zhi Yun. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift

// RxSwift 中的序列操作
// http://www.alonemonkey.com/2017/03/24/rxswift-part-three/
class E_ViewController: UIViewController {

    lazy var bag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        testZipDemo()
    }
    
    // MARK: 2. zip 用法 - 模拟场景： 需要拿到两个异步请求的结果，进行处理
    func testZipDemo() {
        // 合并两个（或多个）Observable 的值， 但只有两个 Observable 都至少发射一个值才能组合，如果任何一个序列为空，不会合并
        
        // 模拟两个异步请求
        let request1 = Observable<Int>.create { (observableNum) -> Disposable in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                observableNum.onNext(3)
                observableNum.onCompleted()
            })
            return Disposables.create()
        }
        let request2 = Observable<Int>.create { (observableNum) -> Disposable in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                observableNum.onNext(1)
                observableNum.onCompleted()
            })
            return Disposables.create()
        }
        
        // zip 将两个请求的结果进行合并 后，再订阅
        Observable.zip(request1, request2)
            .timeout(3, scheduler: MainScheduler.instance) // 设置超时时间
            .subscribe(onNext: { (num1, num2) in
                print(num1 + num2)
            }, onError: { (error) in
                print(error)
            })
            .disposed(by: bag)
    }
    
    
    // MARK: 1. start with 用法
    func testStartWithDemo() {
        // 在序列之前插入；最后插入的元素数组在最前面
        Observable.of("1", "2", "3")
            .startWith("A")
            .startWith("B", "C")
            .subscribe { (str) in
                print(str)
            }
            .disposed(by: bag)
        /**
         output:
         
         next(B)
         next(C)
         next(A)
         next(1)
         next(2)
         next(3)
         completed
         */
    }
    
}

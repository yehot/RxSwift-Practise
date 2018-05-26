//
//  A_DemoViewController.swift
//  RxSwift-Practise
//
//  Created by yehot on 2018/5/24.
//  Copyright © 2018年 Xin Hua Zhi Yun. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift

class A_DemoViewController: UIViewController {

    lazy var bag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        sample_demo1()
    }
    
    func sample_demo1() {

        // MARK: 1、订阅 button 的 tap 事件
        let btn = UIButton()
        btn.rx.tap
            .subscribe { (event) in
                print(event) // event 类型是 (Event<Void>)
            }
            .disposed(by: bag)
        
        // MARK: 2、订阅 textField.text
        let textField = UITextField()
        
        // subscribe(on: )
        textField.rx.text
            .subscribe { (event: Event<String?>) in
                print(event.element as Any)  // 需要解包两次
            }
            .disposed(by: bag)
        
        // subscribe(onNext:) 的完整写法：
        textField.rx.text
            .subscribe(onNext: { (text) in
                print(text!)
            }, onError: { (err) in }, onCompleted: {}) {
                
            }
            .disposed(by: bag)
        
        // subscribe(onNext:) 的省略写法，默认参数可以不传
        textField.rx.text
            .subscribe(onNext: { (text) in
                print(text!)
            })
            .disposed(by: bag)
        
        
        // MARK: 3、UILabel.text 绑定 textField.text
        let label = UILabel()
        // 是 被观察的对象，bind to； 而不是观察者主动去 bind？？
        textField.rx.text
            .bind(to: label.rx.text)
            .disposed(by: bag)
        
        
        // MARK: 4、label 观察 self.text 变化
        label.rx.observe(String.self, "text")
            .subscribe(onNext: { (str) in
                print(str!)
            }).disposed(by: bag)
    }
}

//
//  B_DemoViewController.swift
//  RxSwift-Practise
//
//  Created by yehot on 2018/5/24.
//  Copyright © 2018年 Xin Hua Zhi Yun. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift

// https://medium.com/@DianQK/rxswift-%E5%BC%82%E6%AD%A5%E9%97%AE%E9%A2%98-d26c8c9531ff
// 异步加载 image
class B_DemoViewController: UIViewController {

    lazy var bag = DisposeBag()
    let button = UIButton(frame: CGRect.init(x: 100, y: 100, width: 100, height: 100))

    override func viewDidLoad() {
        super.viewDidLoad()

        button.setTitle("测试", for: .normal)
        button.setTitleColor(.blue, for: .normal)
        view.addSubview(button)
        
//        normal_LoadImageFromUrl()
//        rx_dataWithImageUrl()
        rx_loadImageWithUrl()
    }

    // MARK: 1. 普通加载一张 image
    func normal_LoadImageFromUrl() {
        let imageURL = URL(string: "https://github.com/fluidicon.png")!
        URLSession.shared.dataTask(with: imageURL) { (data, _, _) in
            let image = UIImage(data: data!)
            DispatchQueue.main.async {
                print("normal: self.imageView.image = ")
                print(image!);
            }
        }.resume()
    }
    
    //  MARK: 2. rx 加载 image
    /**
     0. 主要表现 rx 的思路：
         - 将 异步代码、线程切换 转换为流式的处理过程
         - Data with contentsOf url 加载 web image，是阻塞式的，将其放在子线程，异步执行
         - 对异步加载 Data 的结果，进行订阅，并切换到主线程加载 UI
     
     1. map 是个闭包，形式是 { (入参) -> 返回值类型 in
                            return xxx
                        }
     2. map 简写形式：
         - 无入参，直接 return ，Swift 会推断出返回值类型；
         - 有入参，不显式写， 直接 return，也会推断出返回值类型；
     3. map 后，跟 map ，获取的是上一步操作的返回值，作为此次 map 的入参
     
     4. observeOn ，在 xx 线程进行监听：
         - SerialDispatchQueueScheduler 串行，异步线程；
         - MainScheduler.instance 主线程
     
     5. observeOn 后 跟 map，是转换线程后，继续处理
        observeOn 后 跟 subscribe，是订阅
     
     6. 此例中，并没有直接使用 URLSession
     
     */
    func rx_dataWithImageUrl() {
        button.rx.tap
            .map { return "https://github.com/fluidicon.png" }
            .map { str in return URL(string: str) }
            .observeOn(SerialDispatchQueueScheduler(qos: .background)) // 串行队列
            .map { url in return try Data(contentsOf: url!)}
            .map { (data) -> UIImage in
                return UIImage(data: data)!         // 完整写法
            }
            .observeOn(MainScheduler.instance)
            .subscribe { (image) in
                print("rx: self.imageView.image = ")
                print(image)
            }.disposed(by: bag)
    }
    
    
    //  MARK: 3. 使用 rx 封装的 URLSession 方式
    func rx_loadImageWithUrl() {
        button.rx.tap
            .map { return "https://github.com/fluidicon.png" }
            .map { str in return URL(string: str)! }
            .map { imgUrl in URLRequest.init(url: imgUrl) }
            .flatMap { (urlRequest) -> Observable<Data> in
                return URLSession.shared.rx.data(request: urlRequest)
            }
            .map { data in return UIImage.init(data: data) }
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { (image) in
                print("urlsession rx: self.imageView.image = ")
                print(image!)
            }, onError: { (err) in
            }) // 省略了其它情况 onCompleted:, onDisposed:
            .disposed(by: bag)
        
        /**
         1. 对 url session 进行了 rx 扩展
         
         2. 使用 subscribe(onNext:) 代替 subscribe(on:）
         
         3.map 只能同步的传递、变换数据
         flatMap 可以既可以同步的处理数据，也可以异步的处理数据
         */
    }
}

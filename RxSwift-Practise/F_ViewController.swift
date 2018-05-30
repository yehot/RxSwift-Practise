//
//  F_ViewController.swift
//  RxSwift-Practise
//
//  Created by yehot on 2018/5/29.
//  Copyright © 2018年 Xin Hua Zhi Yun. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift

// 录音笔记 model
class NoteModel {
    // 笔记的本地 id，创建笔记时生成的
    let localID: String
    
    // 笔记的 serverID ，向服务端申请
    var serverID : String?
    
    var title: String
    var isTitleNeedUpload = false
    
    var content: String
    var isContentNeedUpload = false

    // 笔记录音的 mp3 文件，上传前需要先申请 signature
    var mp3FilePath: String {
        get {
            return "Library/Cache/" + localID + ".mp3"
        }
    }
    init(localID: String, title: String, content: String) {
        self.localID = localID
        self.title = title
        self.content = content
    }
}

enum Action: String {
    case uploadTitle
    case uploadContent
    case uploadMp3
}

// 一个笔记可以对应 N 个 Task
struct NoteTask {
    let serverID: String
    let action: Action
}

enum NoteError: Error {
    case requestFail(String)
}

// MARK: -

/**
 模拟一个比较复杂的场景:
 
 1. 一个语音笔记类应用，创建的笔记会保存在本地，笔记生产完成后进行上传；
     - 如果没有网络时产生的笔记，网络恢复后进行上传；
     - 如果没有网络时，修改了笔记的 title 或 content，网络恢复后进行上传；
     - 笔记需要上传的部分包括：title、content、mp3 录音；
     - 非 wifi 下，不上传 Mp3 文件；
 2. 笔记上传流程：
     - 笔记上传前，需要先请求一个 serverID；
     - 录音 Mp3 文件上传前，需要先申请 signature；
     - 开始上传某条笔记时，该笔记的 icon 开始旋转动画；
     - 单条笔记上传完成，上传动画结束；
 3. ❗️难点：一个上传动作，可能包含多条笔记：
     - 有的笔记需要先申请 serverID，然后依次上传 title、content、申请 signature、上传 Mp3
     - 有的笔记只需要上传 title、有的笔记只需要上传 Mp3 文件；
     - 上传过程中可能某条笔记的某一步上传动作失败：
         - 需要跳过这条笔记继续下一条
         - 或者，如果是网络原因、token 过期等，需要结束整个流程
 */
class F_ViewController: UIViewController {

    lazy var bag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let noteList = mockNoteListFromDB()
        startUpload(noteList: noteList)
    }
    
    deinit {
        print("+++++ deinit +++++")
    }
    
    // 模拟 class SyncService
    func startUpload(noteList: [NoteModel]) {
        Observable.from(noteList)
            .subscribeOn(SerialDispatchQueueScheduler(qos: .background))
            .concatMap { (noteModel) in
                return self.uploadSingleNote(noteModel)
            }
            .subscribeOn(SerialDispatchQueueScheduler(qos: .background))
            .subscribe(onNext: { (serverID, isSuccess) in
                let str = String(isSuccess)
                print("笔记 " + serverID + " 完成：" + str)
                // 完成一个，从 noteModels 队列中移除一个；更新页面状态
                // if !isSuccess 处理错误的情况
            }, onError: { (error) in
                print(error)
                print("中止同步任务")
            }, onCompleted: {
                print("===== 全部笔记同步完成 =====")
                // 同步完成，移除队列中的 noteModels； 更新页面
            })
            .disposed(by: bag)
    }
    
    func uploadSingleNote(_ noteModel: NoteModel) -> Observable<(String, Bool)> {
       return Observable.just(noteModel)
                .filter({ (noteModel) -> Bool in
                    return noteModel.serverID?.isEmpty == false // 判断是否有 serverAudioID
                })
                .ifEmpty(switchTo: sendGetServerAudioIdRequest(note: noteModel)) // 没有 serverID 的，异步申请一个
                .map { (noteModel) -> [NoteTask] in
                    print("------ 开始 handle 笔记: " + noteModel.serverID! + " -----")
                    return self.noteTasks(from: noteModel) // note model 转为 [task]
                }
                .flatMap { (taskArray) -> Observable<NoteTask> in
                    return Observable.from(taskArray)
                }
                .concatMap { (task) -> Observable<(String, Bool)> in
                    return self.doUploadAction(with: task)
                }
    }

    // MARK: - mock request
    
    func sendGetServerAudioIdRequest(note: NoteModel) -> Observable<NoteModel> {
        
        return Observable.create({ (observer) -> Disposable in
            let isRequestSuccess = note.localID != "local_id_all_success"
//            isRequestSuccess = note.localID != "local_id_4" // 打开注释，模拟同步过程中，有某条笔记失败的情况
            if isRequestSuccess {   // 模拟请求过程
                print("请求 serverID for note " + note.localID)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                    note.serverID = "serverID_" + UUID.init().uuidString
                    observer.onNext(note) // 申请成功
                    observer.onCompleted()
                })
            } else {
                // 如果不 onError，则即使中间有某条笔记同步失败，仍然会执行下一条笔记的同步动作
                observer.onError(NoteError.requestFail("笔记 " + note.localID + " 申请 servrAudioID 失败"))
                observer.onCompleted()
            }
            return Disposables.create()
        })
    }
    
    func sendUploadMp3Request(serverID: String) -> Observable<(String, Bool)> {
        return Observable.create({ (obserable) -> Disposable in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                print("申请笔记 " + serverID + " 的 signature，上传 mp3")
                obserable.onNext((serverID + " Upload Mp3 动作" , true))
                obserable.onCompleted()
            })
            return Disposables.create()
        })
    }
    
    func sendUploadContentRequest(serverID: String) -> Observable<(String, Bool)> {
        return Observable.create({ (obserable) -> Disposable in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                print("上传笔记 " + serverID + " 的 content")
                obserable.onNext((serverID + " uploap content 动作" , true))
                obserable.onCompleted()
            })
            return Disposables.create()
        })
    }
    
    func sendUploadTitleRequest(serverID: String) -> Observable<(String, Bool)> {
        return Observable.create({ (obserable) -> Disposable in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                print("上传笔记 " + serverID + " 的 title")
                obserable.onNext((serverID + " uploap title 动作" , true))
                obserable.onCompleted()
            })
            return Disposables.create()
        })
    }
    
    // MARK: - private

    /// util
    func doUploadAction(with task: NoteTask) -> Observable<(String, Bool)>  {
        switch task.action {
        case .uploadTitle:
            return sendUploadTitleRequest(serverID: task.serverID)
            
        case .uploadContent:
            return sendUploadContentRequest(serverID: task.serverID)
            
        case .uploadMp3:
            return sendUploadMp3Request(serverID: task.serverID)
        }
    }
    
    /// 将一个 note 中需要上传的各个部分，转为一个个的 upload task ，放入 array
    func noteTasks(from noteModel: NoteModel) -> [NoteTask] {
        if let serverID = noteModel.serverID {
            var tasks = [NoteTask]()
            if noteModel.isTitleNeedUpload {
                tasks.append(NoteTask.init(serverID: serverID, action: .uploadTitle))
            }
            if noteModel.isContentNeedUpload {
                tasks.append(NoteTask.init(serverID: serverID, action: .uploadContent))
            }
            tasks.append(NoteTask.init(serverID: serverID, action: .uploadMp3))
            return tasks
        } else {
            return []   // 没有需要上传的部分，空 task array
        }
    }
    
    /// mock 数据
    func mockNoteListFromDB() -> [NoteModel] {
        
        // 有 serverID 的笔记，只有有变更的需要上传
        let note1 = NoteModel.init(localID: "local_id_1", title: "title1", content: "笔记1")
        note1.serverID = "serverID_1"
        note1.isTitleNeedUpload = true
        let note2 = NoteModel.init(localID: "local_id_2", title: "title2", content: "笔记2")
        note2.serverID = "serverID_2"
        note2.isContentNeedUpload = true

        // 没有 serverID 的笔记，所有内容都需要上传
        let note3 = NoteModel.init(localID: "local_id_3", title: "title3", content: "笔记3")
        note3.isContentNeedUpload = true
        note3.isTitleNeedUpload = true
        
        let note4 = NoteModel.init(localID: "local_id_4", title: "title4", content: "笔记4")
        let note5 = NoteModel.init(localID: "local_id_5", title: "title5", content: "笔记5")
        
        return [note1, note2, note3, note4, note5]
    }
}

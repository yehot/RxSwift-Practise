//
//  NoteSyncService.swift
//  RxSwift-Practise
//
//  Created by yehot on 2018/6/6.
//  Copyright © 2018年 Xin Hua Zhi Yun. All rights reserved.
//

import Foundation
import RxSwift

enum Result<T, E: Error> {
    case success(T)
    case failure(E)
    case completed
}

class NoteSyncService {
    
    static let shared = NoteSyncService()
    
    private lazy var bag = DisposeBag()

    func startSync(noteList: [NoteModel], completionHandler: @escaping (Result<String, NoteError>) -> Void) {
        Observable.from(noteList)
            .subscribeOn(SerialDispatchQueueScheduler(qos: .background))
            .concatMap { (noteModel) -> Observable<(String, Action, Bool)> in
                return self.uploadSingleNote(noteModel, completion: completionHandler)
            }
            .subscribe(onNext: { (serverID, action, isSuccess) in
                // 这里 onNext 的并不是 单条笔记同步完成，仅仅是此条笔记完成一个动作
                print("😄 笔记 \(serverID) \(action.rawValue) 成功")
            }, onError: { (err) in
                completionHandler(.failure(err as! NoteError))
            }, onCompleted: {
                completionHandler(.completed)
            })
            .disposed(by: bag)
    }
    
    private func uploadSingleNote(_ noteModel: NoteModel, completion: @escaping (Result<String, NoteError>) -> Void) -> Observable<(String, Action, Bool)> {
        return Observable.just(noteModel)
            .filter({ (noteModel) -> Bool in
                print("\n------ ↓ 开始 handle 笔记: \(noteModel.localID) -----")
                return noteModel.serverID?.isEmpty == false // 判断是否有 serverAudioID
            })
            .ifEmpty(switchTo: sendGetServerAudioIdRequest(note: noteModel)) // 没有 serverID 的，异步申请一个
            .map { (noteModel) -> [NoteTask] in
                return self.noteTasks(from: noteModel) // note model 转为 [task]
            }
            .flatMap { (taskArray) -> Observable<NoteTask> in
                return Observable.from(taskArray)
            }
            .concatMap { (task) -> Observable<(String, Action, Bool)> in
                return self.doUploadAction(with: task)
            }
            .do(onCompleted: {
                // 这里 onCompleted 的才是 单条笔记同步完成
                completion(.success(noteModel.serverID!))
            })
    }
    
    // MARK: - mock request
    /// 请求 Server Audio Id
    private func sendGetServerAudioIdRequest(note: NoteModel) -> Observable<NoteModel> {
        
        return Observable.create({ (observer) -> Disposable in
            let isRequestSuccess = note.localID != ""
            
            // MARK: 打开注释，可以模拟同步过程中，有某条笔记失败的情况
            // let isRequestSuccess = note.localID != "local_id_4"
            
            if isRequestSuccess {   // 模拟请求过程
                print("① 请求 serverID for note:  \(note.localID)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                    // 请求成功时，需要将 serverID 写入数据库（写入成功才能 onNext）
                    note.serverID = "serverID_" + UUID.init().uuidString
                    observer.onNext(note) // 申请成功
                    observer.onCompleted()
                })
            } else {
                observer.onError(NoteError.requestFail("笔记 \(note.localID) 申请 servrAudioID 失败"))
                // onError 后，可以不 onCompleted()，这样则即使中间有某条笔记同步失败，仍然会执行下一条笔记的同步动作
                observer.onCompleted()
            }
            return Disposables.create()
        })
    }
    
    /// 上传 mp3
    private func sendUploadMp3Request(serverID: String) -> Observable<(String, Action, Bool)> {
        return Observable.create({ (obserable) -> Disposable in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                print("④ 执行申请笔记 \(serverID) 的 signature，上传 mp3")
                obserable.onNext((serverID, .uploadMp3, true))
                obserable.onCompleted()
            })
            return Disposables.create()
        })
    }
    
    /// 上传 content
    private func sendUploadContentRequest(serverID: String) -> Observable<(String, Action, Bool)> {
        return Observable.create({ (obserable) -> Disposable in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                print("③ 执行上传笔记 \(serverID) 的 content")
                // 请求成功时，需要将 上传笔记 content 的状态写入数据库（写入成功才能 onNext）
                obserable.onNext((serverID, .uploadContent, true))
                obserable.onCompleted()
            })
            return Disposables.create()
        })
    }
    
    /// 上传 title
    private func sendUploadTitleRequest(serverID: String) -> Observable<(String, Action, Bool)> {
        return Observable.create({ (obserable) -> Disposable in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                print("② 执行上传笔记 \(serverID) 的 title")
                // 请求成功时，需要将 上传笔记 title 的状态写入数据库（写入成功才能 onNext）
                obserable.onNext((serverID , .uploadTitle, true))
                obserable.onCompleted()
            })
            return Disposables.create()
        })
    }
    
    /// 删除笔记
    private func sendDeleteNoteRequest(serverID: String) -> Observable<(String, Action, Bool)> {
        return Observable.create({ (obserable) -> Disposable in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                print("⑤ 执行删除笔记: \(serverID)")
                // 请求成功时，需要将 上传笔记 title 的状态写入数据库（写入成功才能 onNext）
                obserable.onNext((serverID, .uploadTitle, true))
                obserable.onCompleted()
            })
            return Disposables.create()
        })
    }
    
    // MARK: - util
    private func doUploadAction(with task: NoteTask) -> Observable<(String, Action, Bool)>  {
        switch task.action {
        case .uploadTitle:
            return sendUploadTitleRequest(serverID: task.serverID)
            
        case .uploadContent:
            return sendUploadContentRequest(serverID: task.serverID)
            
        case .uploadMp3:
            return sendUploadMp3Request(serverID: task.serverID)
            
        case .deleteNote:
            return sendDeleteNoteRequest(serverID: task.serverID)
        }
    }
    
    /// 将一个 note 中需要上传的各个部分，转为一个个的 upload task ，放入 array
    private func noteTasks(from noteModel: NoteModel) -> [NoteTask] {
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
}

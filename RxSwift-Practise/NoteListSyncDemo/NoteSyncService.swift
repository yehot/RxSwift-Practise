//
//  NoteSyncService.swift
//  RxSwift-Practise
//
//  Created by yehot on 2018/6/6.
//  Copyright © 2018年 Xin Hua Zhi Yun. All rights reserved.
//

import Foundation
import RxSwift

class NoteSyncService {
    
    static let shared = NoteSyncService()
    
    private lazy var bag = DisposeBag()

    func startSync(noteList: [NoteModel]) {
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
    
    private func sendGetServerAudioIdRequest(note: NoteModel) -> Observable<NoteModel> {
        
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
    
    private func sendUploadMp3Request(serverID: String) -> Observable<(String, Bool)> {
        return Observable.create({ (obserable) -> Disposable in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                print("申请笔记 " + serverID + " 的 signature，上传 mp3")
                obserable.onNext((serverID + " Upload Mp3 动作" , true))
                obserable.onCompleted()
            })
            return Disposables.create()
        })
    }
    
    private func sendUploadContentRequest(serverID: String) -> Observable<(String, Bool)> {
        return Observable.create({ (obserable) -> Disposable in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                print("上传笔记 " + serverID + " 的 content")
                obserable.onNext((serverID + " uploap content 动作" , true))
                obserable.onCompleted()
            })
            return Disposables.create()
        })
    }
    
    private func sendUploadTitleRequest(serverID: String) -> Observable<(String, Bool)> {
        return Observable.create({ (obserable) -> Disposable in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                print("上传笔记 " + serverID + " 的 title")
                obserable.onNext((serverID + " uploap title 动作" , true))
                obserable.onCompleted()
            })
            return Disposables.create()
        })
    }
    
    // MARK: - util
    private func doUploadAction(with task: NoteTask) -> Observable<(String, Bool)>  {
        switch task.action {
        case .uploadTitle:
            return sendUploadTitleRequest(serverID: task.serverID)
            
        case .uploadContent:
            return sendUploadContentRequest(serverID: task.serverID)
            
        case .uploadMp3:
            return sendUploadMp3Request(serverID: task.serverID)
        case .deleteNote:
            // todo: 发送删除此条笔记的请求
            return Observable.empty()
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

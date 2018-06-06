//
//  F_ViewController.swift
//  RxSwift-Practise
//
//  Created by yehot on 2018/5/29.
//  Copyright © 2018年 Xin Hua Zhi Yun. All rights reserved.
//

import UIKit
import RxSwift

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
    private lazy var bag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let noteList = mock_noteListFromDatabase()
        NoteSyncService.shared.startSync(noteList: noteList, completionHandler: { (result) in
            switch result {
            case .success(let (serverID)):
                print("------ ↑ 笔记: \(serverID) 处理完成 ----- \n")
                // 完成一个，从 noteModels 队列中移除一个；更新页面状态
            case .failure(let error):
                print(error)
                print("❌ 中止同步任务？")
            case .completed:
                print("===== ✅ 全部笔记同步完成 =====")
                // 同步完成，移除队列中的 noteModels； 更新页面
            }
        })
    }
    
    deinit {
        print("+++++ deinit +++++")
    }

    // MARK: - pirvate

    /// mock 数据
    func mock_noteListFromDatabase() -> [NoteModel] {
        
        // 1、有 serverID 的笔记（只有有变更的部分需要上传）
        let note1 = NoteModel.init(localID: "local_id_1", title: "title1", content: "笔记1")
        note1.serverID = "serverID_1"
        note1.isTitleNeedUpload = true
        
        let note2 = NoteModel.init(localID: "local_id_2", title: "title2", content: "笔记2")
        note2.serverID = "serverID_2"
        note2.isContentNeedUpload = true

        // 2、没有 serverID 的笔记（断网产生的：所有内容都需要上传）
        let note3 = NoteModel.init(localID: "local_id_3", title: "title3", content: "笔记3")
        note3.isContentNeedUpload = true
        note3.isTitleNeedUpload = true
        
        let note4 = NoteModel.init(localID: "local_id_4", title: "title4", content: "笔记4") // mock 需要上传 mp3 的数据
        let note5 = NoteModel.init(localID: "local_id_5", title: "title5", content: "笔记5")
        
        return [note1, note2, note3, note4, note5]
    }
}

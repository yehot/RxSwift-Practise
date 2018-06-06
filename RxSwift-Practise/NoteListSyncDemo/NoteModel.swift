//
//  NoteModel.swift
//  RxSwift-Practise
//
//  Created by yehot on 2018/6/6.
//  Copyright © 2018年 Xin Hua Zhi Yun. All rights reserved.
//

import Foundation

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
    case deleteNote
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

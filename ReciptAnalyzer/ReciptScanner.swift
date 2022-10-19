//
//  ReciptScanner.swift
//  ReciptAnalyzer
//
//  Created by Kenta Machida on 2022/08/14.
//

import Foundation
import VisionKit
import Alamofire
import os

let loggerScanner = Logger(subsystem: "com.lifeimp.reciptanalyzer", category: "Scanner")

/// ContentViewとの情報連携のためObservableObjectプロトコルに準拠
final class ScannerModel: NSObject, ObservableObject {
    @Published var imageArray: [UIImage] = []
    @Published var isImageSaved: Bool = false
    @Published var files: [File] = [File]()
    
    /// ドキュメントスキャナを呼び出す関数
    /// - Returns: ドキュメントスキャナのコントローラ
    func getDocumentCameraViewController() -> VNDocumentCameraViewController {
        loggerScanner.info("start getDocumentCameraViewController")
        let vc = VNDocumentCameraViewController()
        vc.delegate = self
        loggerScanner.info("end getDocumentCameraViewController")
        return vc
    }
}

// delegate元としてのI/Fなどを定義
extension ScannerModel: VNDocumentCameraViewControllerDelegate {

    /// スキャナがキャンセル際の動作？を定義する関数
    /// - Parameter controller: ドキュメントスキャナのコントローラ
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        loggerScanner.info("start documentCameraViewControllerDidCancel")
        controller.dismiss(animated: true)
        loggerScanner.info("end documentCameraViewControllerDidCancel")
    }
    
    /// スキャナを終了させる前に実行される関数
    /// - Parameters:
    ///   - controller: ドキュメントスキャナのコントローラ
    ///   - scan: 処理の対象となるスキャン情報
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        loggerScanner.info("start documentCameraViewController")
        // スキャンした複数ドキュメントに対する処理を想定
        for i in 0..<scan.pageCount {
            let scaned_image = scan.imageOfPage(at: i)
            let file_name = "reciptImage\(i).png"
            // このコントローラ内でアップロードをすると呼びだしもとのViewと連携が難しいので
            // ローカルに保存する処理までとして、アップロード処理は大本のViewで実施する。
            let lfu = LocalFileUtils()
            // スキャンしたドキュメントをアプリ内ローカルフォルダに保存
            lfu.saveFileToDocumentDir(scaned_image: scaned_image, fileName: file_name)
            // 保存済の全ファイルを取得し、ContentViewに渡すためのバインド変数に格納
            self.files = lfu.getAllFilesInDocumentDir()
            self.isImageSaved = true
        }
        controller.dismiss(animated: true)
        loggerScanner.info("end documentCameraViewController")
    }
    
    @objc func image(image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer) {
        loggerScanner.info("start image")
        if let error = error {
            loggerScanner.error("Failed to save photo: \(error)")
        } else {
            loggerScanner.info("Photo saved successfully.")
        }
        loggerScanner.info("end documentCameraViewController")
    }
}

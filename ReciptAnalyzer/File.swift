//
//  File.swift
//  ReciptAnalyzer
//
//  Created by Kenta Machida on 2022/09/11.
//

import Foundation
import VisionKit
import Alamofire
import SwiftUI
import os

let loggerFile = Logger(subsystem: "com.lifeimp.reciptanalyzer", category: "File")

/* ObservedObjectとしてファイルを扱うためのFile型を定義 */
struct File: Identifiable, Codable, Hashable {
    var id: String
    var file_name: String
}

/// アプリ内ローカルファイルを管理するクラス
class LocalFileUtils {
    // アプリ内データの保存先のパス（AppData/Documents）を表す
    private var documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    /// レシート画像登録APIのレスポンスを表す型
    struct uploadReciptImageResponse: Decodable {
        let id: String
    }
    
    /// レシート画像解析関数
    /// - Parameters:
    ///   - id: 解析対象の画像が登録されているidを示す（レシート画像登録APIの返り値を想定）
    ///   - completionHandler: APコールバック関数
    func getAnalyzedReciptInfo(id: String, completionHandler: @escaping (Swift.Result<String, Error>) -> Void) {
        callGetAnalyzedReciptInfo(id: id, completion: completionHandler)
    }

    // 内部関数（getAnalyzedReciptInfoはこの関数をラップ）
    func callGetAnalyzedReciptInfo(id: String, completion: @escaping (Swift.Result<String, Error>) -> Void) {
        loggerFile.info("start callGetAnalyzedReciptInfo")
        // GCP GPI GatewayのURL（裏ではレシート解析Functionが実行される）
        let url = "https://life-improvement-api-gateway-4jjtk5st.uc.gateway.dev/recipt/\(id)"
        // Almofireを用いてAPIコール
        AF.request(url).responseString { (response) in
            // レスポンスをString型で期待し、結果を受け取ったらコールバック関数の引数に値を渡す
            switch response.result {
                case .success(let value):
                    loggerFile.info("success callGetAnalyzedReciptInfo")
                    completion(.success(value))
                case .failure(let error):
                    loggerFile.error("failer callGetAnalyzedReciptInfo")
                    completion(.failure(error))
            }
        }
    }
    
    /// レシート画像登録関数
    /// - Parameters:
    ///   - files: 登録対象の複数ファイルを表す
    ///   - completionHandler: APIコールバック関数
    func uploadReciptImageToGCS(files: [File], completionHandler: @escaping (Swift.Result<String, Error>) -> Void) {
        callPostReciptImage(files: files, completion: completionHandler)
    }
    
    // 内部関数（uploadReciptImageToGCSはこの関数をラップ）
    func callPostReciptImage(files: [File], completion: @escaping (Swift.Result<String, Error>) -> Void) {
        loggerFile.info("start callPostReciptImage")
        // GCP API GatewayのURL（裏ではレシート画像登録Functionが実行される）
        let url = "https://life-improvement-api-gateway-4jjtk5st.uc.gateway.dev/recipt"
        // HTTPでファイルを送信するためのヘッダを設定
        let headers: HTTPHeaders = [
            "Content-type": "multipart/form-data"
        ]
        
        // Almofireを用いてAPIコール
        AF.upload(multipartFormData: { (multipartFormData) in
            for file in files {
                let file_name = file.file_name
                let path = self.documentDirectoryFileURL.appendingPathComponent(file_name).path
                let image = UIImage(contentsOfFile: path)
                // UIImage → Data型へ変換
                guard let imageData = image?.pngData() else { print("error: imageData convert"); return }
                // 複数ファイルを想定（配列に追記）
                multipartFormData.append(imageData, withName: file_name, fileName: file_name, mimeType: "image/png")
            }
        }, to: url, method: .post, headers: headers).responseDecodable(of: uploadReciptImageResponse.self) {
        (response) in
            // レスポンス：画像登録APIコールの返り値JSONを期待し、結果を受け取ったらコールバック関数の引数に渡す
            if let statusCode = response.response?.statusCode {
                    if case 200...299 = statusCode{
                        switch(response.result) {
                            case .success(let value):
                                loggerFile.info("end callPostReciptImage return \(statusCode)")
                                completion(.success(value.id))
                            case .failure(let error):
                                loggerFile.error("failure callPostReciptImage return \(statusCode)")
                                completion(.failure(error))
                        }
                    } else {
                        loggerFile.error("failure callPostReciptImage return \(statusCode)")
                    }
              }
        }
    }

    /// 撮影した写真をローカルに保存する関数
    /// - Parameters:
    ///   - scaned_image: 撮影した写真イメージ
    ///   - fileName: 保存先ファイル名
    func saveFileToDocumentDir(scaned_image: UIImage, fileName: String) {
        loggerFile.info("start saveFileToDocumentDir")
        // 保存先ファイルパス
        let path = self.documentDirectoryFileURL.appendingPathComponent(fileName)
        let pngImageData = scaned_image.pngData()
        do {
            // ファイルとして保存
            try pngImageData!.write(to: path)
        } catch {
            loggerFile.error("failure saveFileToDocumentDir")
        }
        loggerFile.info("end saveFileToDocumentDir")
    }
    
    /// ローカルフォルダの全ファイルを取得する関数
    /// - Returns: ファイルリスト
    func getAllFilesInDocumentDir() -> [File] {
        loggerFile.info("start getAllFilesInDocumentDir")
        guard let directoryContents = try? FileManager.default.contentsOfDirectory(at: documentDirectoryFileURL, includingPropertiesForKeys: nil) else { return [File]() }
        var files: [File] = [File]()
        var id = 0
        for content in directoryContents {
            // ファイル名を取得するためにNSString形式でファイル情報を取得
            let nsfile_path: NSString = content.path as NSString
            // .lastPathComponentを用いてファイル名のみを取得
            let file_name = nsfile_path.lastPathComponent
            let file: File = File(id: "\(id)", file_name: file_name)
            files.append(file)
            id += 1
        }
        loggerFile.info("end getAllFilesInDocumentDir")
        return files
    }
    
    /// ローカルフォルダの全ファイルを削除する関数
    func deleteAllFilesInDocumentDir() {
        loggerFile.info("start deleteAllFilesInDocumentDir")
        guard let directoryContents = try? FileManager.default.contentsOfDirectory(at: documentDirectoryFileURL, includingPropertiesForKeys: nil) else { return }
        for path in directoryContents {
            do {
                try FileManager.default.removeItem(at: path)
            } catch {
                loggerFile.error("failure deleteAllFileInDocumentDir path: \(path)")
            }
        }
        loggerFile.info("end deleteAllFilesInDocumentDir")
    }
    
    /// ローカルフォルダのファイルを削除する関数
    /// - Parameter file_name: 対象のファイル名
    func deleteFileInDocumentDir(file_name: String) {
        loggerFile.info("start deleteFileInDocumentDir")
        // 対象ファイルパス
        let path = documentDirectoryFileURL.appendingPathComponent(file_name)
        do {
            try FileManager.default.removeItem(at: path)
        } catch {
            loggerFile.error("failure deleteFileInDocumentDir path: \(path)")
        }
        loggerFile.info("end deleteFileInDocumentDir")
    }
    
}

//
//  ContentView.swift
//  ReciptAnalyzer
//
//  Created by Kenta Machida on 2022/07/25.
//

import SwiftUI
import os

let loggerContent = Logger(subsystem: "com.lifeimp.reciptanalyzer", category: "Content")

/// メインのUIを提供するView
struct ContentView: View {
    
    var lfm = LocalFileUtils()
    @ObservedObject var scannerModel = ScannerModel()
    @State private var items: [Item] = [Item]()
    @State private var currentId: String = "-1"
    @State private var value: [Double] = [Double](repeating: 0, count: 100)
    @State private var items_tobal_value: Double = 0
    @State private var isCaptured: Bool = false
    @State private var analyzing: Bool = false
    @State private var isAnalyzed: Bool = false
    
    var body: some View {
        
        List {
            // タイトル表示
            HStack(alignment: .center) {
                Spacer()
                Image("title")
                    .resizable()
                    .frame(width: 270.0, height: 36.0)
                    .padding()
                Spacer()
            }
            
            // イメージ画像とともに[Capture]ボタンを表示
            HStack(alignment: .center) {
                Spacer()
                Image("capture-recept") .resizable()
                    .frame(width: 150,height: 150)
                Spacer()
                // ボタンがタップされたときの処理を定義
                Button(action: {
                    loggerContent.info("start [Capture] Button action")
                    // 各種初期化処理
                    lfm.deleteAllFilesInDocumentDir()
                    self.isAnalyzed = false
                    self.scannerModel.files = lfm.getAllFilesInDocumentDir()
                    self.scannerModel.isImageSaved = false
                    self.items_tobal_value = 0
                    self.items = [Item]()
                    // ドキュメントスキャナーへ遷移を移す
                    let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                    let window = windowScene?.windows
                    window?.filter({$0.isKeyWindow}).first?.rootViewController?.present(scannerModel.getDocumentCameraViewController(), animated: true)
                }) {
                    Text("Capture")
                        .fontWeight(.bold)
                        .frame(width: 120, height: 48, alignment: .center)
                        .foregroundColor(Color(.white))
                        .background(Color(.black))
                        .cornerRadius(24)
                }
                .buttonStyle(BorderlessButtonStyle())
                Spacer()
            }
            
            // 矢印イメージを表示
            HStack(alignment: .center) {
                Spacer()
                Image("arrow") .resizable()
                    .frame(width: 80,height: 20,alignment: .center)
                Spacer()
            }
        
            // イメージ画像とともに[Analyze]ボタンを表示
            HStack(alignment: .center) {
                Spacer()
                Image("analyze-recipt") .resizable()
                    .frame(width: 150,height: 170)
                Spacer()
                // ボタンがタップされたときの処理を定義
                Button(action: {
                    // binding<[File]> から [File] へアンラップ
                    let files: [File] = $scannerModel.files.wrappedValue
                
                    if self.$scannerModel.files.count == 0 {
                        loggerContent.error("no image was saved")
                        return
                    }
                    // analyzing = trueの間プログレスバーを表示
                    self.analyzing = true
                
                    // レシート画像登録APIをコール
                    lfm.uploadReciptImageToGCS(files: files) { result in
                        switch result {
                            case .failure(_):
                                loggerContent.error("failure upload recipt image API call")
                            case .success(let value):
                                loggerContent.info("end upload recipt image API call value: \(value)")
                                self.currentId = value
            
                                // レシート解析APIをコール
                                lfm.getAnalyzedReciptInfo(id: self.currentId) { result in
                                    switch result {
                                        case .failure(_):
                                            loggerContent.error("failure analyze recipt Image API call")
                                        case .success(let value):
                                            loggerContent.info("end analyze recipt Image API call")
                                            loggerContent.info("response is \(value)")
                                            let jsonStr: String = value
                                            // レスポンスから商品一覧を取得
                                            self.items += convertJsonToItems(jsonStr: jsonStr)
                                            // 商品一覧から商品の合計額を算出
                                            items_tobal_value += self.items.reduce(0){$0 + $1.total_price}
                                    }
                                    // プログレスバーを非表示
                                    self.analyzing = false
                                    // 商品一覧を表示するためのフラグ立て
                                    isAnalyzed = true
                                }
                        }
                    }
                }) {
                    Text("Analyze")
                        .fontWeight(.bold)
                        .frame(width: 120, height: 48, alignment: .center)
                        .foregroundColor(Color(.white))
                        .background($scannerModel.isImageSaved.wrappedValue ? Color.black: Color(UIColor.lightGray))
                        .cornerRadius(24)
                }
                .buttonStyle(BorderlessButtonStyle())
                // 写真が保存されるまで非表示
                .disabled(!$scannerModel.isImageSaved.wrappedValue)
                Spacer()
            }
            
            // 矢印イメージを表示
            HStack(alignment: .center) {
                Spacer()
                Image("arrow") .resizable()
                    .frame(width: 80,height: 20,alignment: .center)
                Spacer()
            }
            
            // プログレスバーを表示
            if analyzing {
                HStack(alignment: .center) {
                    Spacer()
                    ActivityIndicator()
                    Spacer()
                }
            }
            
            // 商品一覧リストを表示
            if isAnalyzed {
                // GeometryReaderを用いて水平方向の各Viewの配置位置を割合で指定
                GeometryReader { geo in
                    HStack() {
                        Spacer()
                            .frame(width: geo.size.width * 0.3)
                        Text("ちま")
                            .frame(width: geo.size.width * 0.2)
                        Spacer()
                            .frame(width: geo.size.width * 0.3)
                        Text("りお")
                            .frame(width: geo.size.width * 0.2)
                    }
                }
                // 商品数分（商品名, 金額A, スライダー, 金額B, 合計額）を表示
                ForEach(Array(self.items.enumerated()), id: \.offset) { offset, item in
                    // GeometryReaderを用いて水平方向の各Viewの配置位置を割合で指定
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            // 商品名を表示（商品名全体を見れるようスクロールバーで実現）
                            ScrollView(.horizontal) {
                                Text(item.name)
                            }
                                .frame(width:  geo.size.width * 0.3)
                            // 金額Aを計算し表示（商品額 - スライダーの値で実現）
                            Text("\(Int(item.total_price - self.value[offset]))")
                                .lineLimit(nil)
                                .frame(width:  geo.size.width * 0.2)
                            // スライダーを表示（金額を5等分 = /6して調整できるよう設定）
                            Slider(value: self.$value[offset], in: 1...item.total_price, step:floor(item.total_price/6))
                                .frame(width:geo.size.width *  0.3)
                            // 金額Bを計算し表示（スライダーの値で実現）
                            Text("\(Int(self.value [offset]))")
                                .lineLimit(nil)
                                .frame(width:geo.size.width *  0.2)
                        }
                    }
                    // 補足情報がある場合には表示
                    if item.remarks != "" {
                        // GeometryReaderを用いて水平方向の各Viewの配置位置を割合で指定
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                // 商品名を表示（商品名全体を見れるようスクロールバーで実現）
                                ScrollView(.horizontal) {
                                    Text(item.remarks)
                                }
                                    .frame(width:  geo.size.width * 0.3)
                                // 空文字で表示位置を調整
                                Text("")
                                    .lineLimit(nil)
                                    .frame(width:  geo.size.width * 0.7)
                            }
                        }
                    }
                    
                }
                // GeometryReaderを用いて水平方向の各Viewの配置位置を割合で指定
                GeometryReader { geo in
                    HStack() {
                        Spacer()
                            .frame(width: geo.size.width * 0.3)
                        // Aさんの支払いの合計額を表示
                        Text("\(Int(self.items_tobal_value -    self.value.reduce(0, +)))")
                            .frame(width: geo.size.width * 0.2)
                        Spacer()
                            .frame(width: geo.size.width * 0.3)
                        // Bさんの支払いの合計額を表示
                        Text("\(Int(self.value.reduce(0, +)))")
                            .frame(width: geo.size.width * 0.2)
                    }
                }
            }
        }
    }
}

// プログレスバーの定義
struct ActivityIndicator: UIViewRepresentable {
    func makeUIView(context: UIViewRepresentableContext<ActivityIndicator>) -> UIActivityIndicatorView {
        return UIActivityIndicatorView(style: .large)
    }
    func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<ActivityIndicator>) {
        uiView.startAnimating()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


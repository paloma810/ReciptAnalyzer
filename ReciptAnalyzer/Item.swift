//
//  Item.swift
//  ReciptAnalyzer
//
//  Created by Kenta Machida on 2022/08/24.
//

import Foundation
import SwiftUI
import os

let loggerItem = Logger(subsystem: "com.lifeimp.reciptanalyzer", category: "Item")

/// レシート解析結果のレスポンス（購入情報）を表す型
struct ItemInfo: Codable, Hashable {
    var shop_name: String
    var item_info: [Item]
}

/// レシート解析結果のレスポンスの一部（購入商品一覧）を表す型
struct Item: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var total_price: Double
    var price: Double
    var buyer_f: Int
    var remarks: String
}

/// レスポンスのJSONから購入商品一覧をまとめる関数
/// （複数レシートを解析した結果ItemInfoは配列型になる可能性があるため）
/// - Parameter jsonStr: レシート解析関数のレスポンス
/// - Returns: 購入商品一覧
func convertJsonToItems(jsonStr: String) -> [Item] {
    loggerItem.info("start convertJsonToItems")
    // レスポンスのJSONを[ItemInfo]型に変換する関数の呼び出し
    let itemInfos: [ItemInfo] = convertJsonToItemInfos(jsonStr: jsonStr)
    // [ItemInfo] → [Item] に集約
    let items: [Item] = itemInfos.reduce([Item]()){ $0 + $1.item_info }
    loggerItem.info("end convertJsonToItems")
    return items
}

/// レスポンスのJSONを[ItemInfo型に変換する関数
/// - Parameter jsonStr: レシート解析関数のレスポンス
/// - Returns: 購入情報
func convertJsonToItemInfos(jsonStr: String) -> [ItemInfo] {
    loggerItem.info("start convertJsonToItemInfos")
    let jsonData = String(jsonStr).data(using: .utf8)!
    var itemInfo: [ItemInfo]
    let decoder = JSONDecoder()
    do {
        itemInfo = try decoder.decode([ItemInfo].self, from: jsonData)
        loggerItem.info("end convertJsonToItemInfos")
        return itemInfo
    } catch let error {
        let nsError = error as NSError
        loggerItem.error("failure convertJsonToItemInfos code: \(nsError.userInfo)")
        return []
    }
}

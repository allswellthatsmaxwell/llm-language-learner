//
//  TitleStore.swift
//  LLMLL
//
//  Created by Maxwell Peterson on 11/21/23.
//

import Foundation

class TitleStore: ObservableObject {
    @Published var titles: [UUID:String]
    private var fileURL = getDocumentsDirectory().appendingPathComponent("titles.json")
    
    init() {
        self.titles = [:]
        load()
    }
    
    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            titles = try decoder.decode([UUID:String].self, from: data)
        } catch {
            print("Error loading titles: \(error.localizedDescription)")
        }
    }
    
    func save() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(titles)
            try data.write(to: fileURL, options: [.atomicWrite, .completeFileProtection])
        } catch {
            print("Error saving titles: \(error.localizedDescription)")
        }
    }
    
    // add entry for specific chat id
    func addTitle(chatId: UUID, title: String) {
        self.titles[chatId] = title
        save()
    }
    
    
}

//
//  Search_TCAApp.swift
//  Search-TCA
//
//  Created by Rifqi Fadhlillah on 09/08/21.
//

import SwiftUI
import ComposableArchitecture

@main
struct Search_TCAApp: App {
  var body: some Scene {
    WindowGroup {
      NavigationView {
        ContentView(
          store: .init(
            initialState: .init(),
            reducer: appReducer,
            environment: .init(localSearchCompleter: .live)
          )
        )
      }
    }
  }
}

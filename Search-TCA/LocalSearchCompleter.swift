//
//  LocalSearchCompleter.swift
//  LocalSearchCompleter
//
//  Created by Rifqi Fadhlillah on 09/08/21.
//

import ComposableArchitecture
import MapKit
import Combine

struct LocalSearchCompleter {
  var completions: () -> Effect<Result<[MKLocalSearchCompletion], Error>, Never>
  var search: (String) -> Effect<Never, Never>
}

extension LocalSearchCompleter {
  static var live: Self {
    class Delegate: NSObject, MKLocalSearchCompleterDelegate {
      let subscriber: Effect<Result<[MKLocalSearchCompletion], Error>, Never>.Subscriber

      init(subsriber: Effect<Result<[MKLocalSearchCompletion], Error>, Never>.Subscriber) {
        self.subscriber = subsriber
      }

      func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.subscriber.send(.success(completer.results))
      }

      func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        self.subscriber.send(.failure(error))
      }
    }
    let completer = MKLocalSearchCompleter()

    return Self(
      completions: {
        Effect.run { subscriber in
          let delegate = Delegate(subsriber: subscriber)
          completer.delegate = delegate

          return AnyCancellable {
            _ = delegate
          }
        }
      }, search: { queryFragment in
          .fireAndForget {
            completer.queryFragment = queryFragment
          }
      }
    )
  }
}

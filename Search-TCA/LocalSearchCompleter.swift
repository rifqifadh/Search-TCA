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
  var completions: () -> Effect<Result<[LocalSearchCompletion], Error>, Never>
  var search: (String) -> Effect<Never, Never>
}

extension LocalSearchCompleter {
  static var live: Self {
    class Delegate: NSObject, MKLocalSearchCompleterDelegate {
      let subscriber: Effect<Result<[LocalSearchCompletion], Error>, Never>.Subscriber

      init(subsriber: Effect<Result<[LocalSearchCompletion], Error>, Never>.Subscriber) {
        self.subscriber = subsriber
      }

      func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
				self.subscriber.send(
					.success(
						completer.results
							.map(LocalSearchCompletion.init(rawValue:))
					)
				)

        let search = MKLocalSearch(request: .init(completion: completer.results[0]))
        Task {
          let response = try await search.start()
					print(response.mapItems)
        }
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

struct LocalSearchCompletion: Equatable {
	let rawValue: MKLocalSearchCompletion?

	var subtitle: String
	var title: String

	init(rawValue: MKLocalSearchCompletion) {
		self.rawValue = rawValue
		self.subtitle = rawValue.subtitle
		self.title = rawValue.title
	}

	init(subtitle: String, title: String) {
		self.rawValue = nil
		self.subtitle = subtitle
		self.title = title
	}

	static func == (lhs: Self, rhs: Self) -> Bool {
		lhs.subtitle == rhs.subtitle
		&& lhs.title == rhs.title
	}
}

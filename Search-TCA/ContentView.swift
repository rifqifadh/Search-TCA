//
//  ContentView.swift
//  Search-TCA
//
//  Created by Rifqi Fadhlillah on 09/08/21.
//

import SwiftUI
import ComposableArchitecture
import MapKit

struct CoordinateRegion: Equatable {
  var center = LocationCoordinate2D()
  var span = CoordinateSpan()
}

extension CoordinateRegion {
  init(rawValue: MKCoordinateRegion) {
    self.init(
      center: .init(rawValue: rawValue.center),
      span: .init(rawValue: rawValue.span)
    )
  }

  var rawValue: MKCoordinateRegion {
    .init(center: self.center.rawValue, span: self.span.rawValue)
  }
}

struct LocationCoordinate2D: Equatable {
  var latitude: CLLocationDegrees = 0
  var longitude: CLLocationDegrees = 0
}

extension LocationCoordinate2D {
  init(rawValue: CLLocationCoordinate2D) {
    self.init(
      latitude: rawValue.latitude,
      longitude: rawValue.longitude
    )
  }

  var rawValue: CLLocationCoordinate2D {
    .init(latitude: self.latitude,
          longitude: self.longitude)
  }
}

struct CoordinateSpan: Equatable {
  var latitudeDelta: CLLocationDegrees = 0
  var longitudeDelta: CLLocationDegrees = 0
}

extension CoordinateSpan {
  init(rawValue: MKCoordinateSpan) {
    self.init(
      latitudeDelta: rawValue.latitudeDelta,
      longitudeDelta: rawValue.longitudeDelta
    )
  }

  var rawValue: MKCoordinateSpan {
    .init(latitudeDelta: self.latitudeDelta,
          longitudeDelta: self.longitudeDelta
    )
  }
}

extension LocalSearchCompletion: Identifiable {
  var id: [String] { [self.title, self.subtitle] }
}

extension MapItem: Identifiable {
	var id: [String?] { [self.name, self.phoneNumber] }
}

struct AppState: Equatable {
  var query = ""
  var region = CoordinateRegion(
    center: .init(latitude: 40.7, longitude: -74),
    span: .init(latitudeDelta: 0.075, longitudeDelta: 0.075)
  )
  var completions: [LocalSearchCompletion] = []
	var mapItems: [MapItem] = []
}

enum AppAction: Equatable {
  case onAppear
  case queryChanged(String)
  case regionChanged(CoordinateRegion)
  case completionsUpdated(Result<[LocalSearchCompletion], NSError>)
	case searchResponse(Result<LocalSearchClient.Response, NSError>)
	case tappedCompletion(LocalSearchCompletion)
	case searchSubmitted
}

struct AppEnvironment {
	var localSearch: LocalSearchClient
  var localSearchCompleter: LocalSearchCompleter
	var mainQueue: AnySchedulerOf<DispatchQueue>
}

let appReducer = Reducer<
  AppState,
  AppAction,
  AppEnvironment
> { state, action, environment in
  switch action {
    case .onAppear:
      return environment.localSearchCompleter.completions()
				.map { result in
					result.mapError { $0 as NSError }
				}
        .map(AppAction.completionsUpdated)

    case let .completionsUpdated(.success(completions)):
      state.completions = completions
      return .none

    case let .completionsUpdated(.failure(error)):
      // TODO: error handling
      return .none

    case let .queryChanged(query):
      state.query = query
      return environment.localSearchCompleter.search(query)
        .fireAndForget()

    case let .regionChanged(region):
      state.region = region
      return .none

		case let .searchResponse(.success(response)):
			state.region = response.boundingRegion
			state.mapItems = response.mapItems
			return .none

		case let .searchResponse(.failure(error)):
			// TODO: error handling
			return .none

		case let .tappedCompletion(completion):
			state.query = completion.title
			return environment.localSearch.search(completion)
				.mapError { $0 as NSError }
				.receive(on: environment.mainQueue.animation())
				.catchToEffect()
				.map(AppAction.searchResponse)

		case .searchSubmitted:
			let searchRequest = MKLocalSearch.Request()
			searchRequest.naturalLanguageQuery = state.query
			return environment.localSearch.endpoint(searchRequest)
				.mapError { $0 as NSError }
				.receive(on: environment.mainQueue.animation())
				.catchToEffect()
				.map(AppAction.searchResponse)
	}
}

struct ContentView: View {
  let store: Store<AppState, AppAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Map(
        coordinateRegion: viewStore.binding(
          get: \.region.rawValue,
          send: { .regionChanged(.init(rawValue: $0)) }
        ),
				annotationItems: viewStore.mapItems,
				annotationContent: { mapItem in
					MapMarker(coordinate: mapItem.placemark.coordinate)
				}
      )
        .searchable(
          text: viewStore.binding(
            get: \.query,
            send: AppAction.queryChanged
          )
        ) {
          if viewStore.completions.isEmpty {
            EmptySearchPrompt()
          } else {
            ForEach(viewStore.completions) { completion in
							Button(action: { viewStore.send(.tappedCompletion(completion))}) {
								VStack(alignment: .leading) {
									Text(completion.title)
									Text(completion.subtitle)
										.font(.caption)
								}
							}
            }
          }
        }
				.onSubmit(of: .search) {
					viewStore.send(.searchSubmitted)
				}
        .navigationTitle("Places")
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
          viewStore.send(.onAppear)
        }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(
      store: .init(
        initialState: .init(),
        reducer: appReducer,
        environment: .init(
					localSearch: .live,
					localSearchCompleter: .live,
					mainQueue: .main
				)
      )
    )
  }
}

struct EmptySearchPrompt: View {

  var body: some View {
    HStack {
      Text("Recent Searches")
      Spacer()
      Button(action: {}) {
        Text("See all")
      }
    }
    .font(.callout)

    HStack {
      Image(systemName: "magnifyingglass")
      Text("Apple ??? New York")
      Spacer()
    }
    HStack {
      Image(systemName: "magnifyingglass")
      Text("Apple ??? New York")
      Spacer()
    }
    HStack {
      Image(systemName: "magnifyingglass")
      Text("Apple ??? New York")
      Spacer()
    }

    HStack {
      Text("Find nearby")
      Spacer()
      Button(action: {}) {
        Text("See all")
      }
    }
    .padding(.top)
    .font(.callout)

    ScrollView(.horizontal) {
      HStack {
        ForEach(1...2, id: \.self) { _ in
          VStack {
            ForEach(1...2, id: \.self) { _ in
              HStack {
                Image(systemName: "bag.circle.fill")
                  .foregroundStyle(Color.white, Color.red)
                  .font(.title)
                Text("Shopping")
              }
              .padding([.top, .bottom, .trailing],  4)
            }
          }
        }
      }
    }

    HStack {
      Text("Editors??? picks")
      Spacer()
      Button(action: {}) {
        Text("See all")
      }
    }
    .padding(.top)
    .font(.callout)
  }
}

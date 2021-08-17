import MapKit
import ComposableArchitecture

struct LocalSearchClient {
	var search: (LocalSearchCompletion) -> Effect<Response, Error>

	struct Response: Equatable {
		var boundingRegion = CoordinateRegion()
		var mapItems: [MapItem] = []
	}
}

struct MapItem: Equatable {
	var placemark: MKPlacemark
	var pointOfInterestCategory: MKPointOfInterestCategory?
	var isCurrentLocation: Bool
	var name: String?
	var phoneNumber: String?
	var url: URL?
	var timeZone: TimeZone?
}

extension MapItem {
	init(rawValue: MKMapItem) {
		self.placemark = rawValue.placemark
		self.pointOfInterestCategory = rawValue.pointOfInterestCategory
		self.isCurrentLocation = rawValue.isCurrentLocation
		self.name = rawValue.name
		self.phoneNumber = rawValue.phoneNumber
		self.url = rawValue.url
		self.timeZone = rawValue.timeZone
	}
}

extension LocalSearchClient.Response {
	init(rawValue: MKLocalSearch.Response) {
		self.boundingRegion = .init(rawValue: rawValue.boundingRegion)
		self.mapItems = rawValue.mapItems.map { .init(rawValue: $0) }
	}
}

extension LocalSearchClient {
	static let live = Self(
		search: { completion in
				.task {
					.init(
						rawValue:
							try await MKLocalSearch(request: .init(completion: completion.rawValue!))
							.start()
					)
				}
		}
	)
}

extension Effect {
	static func task(
		priority: TaskPriority? = nil,
		operation: @escaping @Sendable () async throws -> Output
	) -> Self
	where Failure == Error {
		.future { callback in
			Task(priority: priority) {
				do {
					callback(.success(try await operation()))
				} catch {
					callback(.failure(error))
				}
			}
		}
	}
}

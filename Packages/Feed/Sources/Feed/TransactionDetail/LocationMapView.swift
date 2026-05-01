import CoreLocation
import MapKit
import SwiftUI
import UIKit

struct LocationMapView: View {
    let address: String

    @State private var coordinate: CLLocationCoordinate2D?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var isGeocoding = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(icon: "mappin.circle.fill", title: "Location")

            if let coordinate {
                Button {
                    openInMaps(coordinate: coordinate)
                } label: {
                    Map(
                        position: $mapPosition,
                        interactionModes: []
                    ) {
                        Marker(address, coordinate: coordinate)
                    }
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .bottomTrailing) {
                        Label("Open in Maps", systemImage: "arrow.up.right.square")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                            .padding(8)
                    }
                }
                .buttonStyle(.plain)
            } else if isGeocoding {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(height: 180)
                    .overlay(ProgressView())
            } else {
                HStack {
                    Text(address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        openInMaps(address: address)
                    } label: {
                        Label("Open in Maps", systemImage: "map")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: address) {
            await geocode()
        }
    }

    private func openInMaps(coordinate: CLLocationCoordinate2D) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = address
        mapItem.openInMaps()
    }

    private func openInMaps(address: String) {
        guard let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "maps://?q=\(encoded)") else { return }
        UIApplication.shared.open(url)
    }

    private func geocode() async {
        isGeocoding = true
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            if let coord = placemarks.first?.location?.coordinate {
                coordinate = coord
                mapPosition = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                ))
            } else {
                coordinate = nil
            }
        } catch {
            coordinate = nil
        }
        isGeocoding = false
    }
}

import AppIntents

public enum TransferDirection: String, AppEnum {
    case incoming
    case outgoing

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Direction")

    public static let caseDisplayRepresentations: [TransferDirection: DisplayRepresentation] = [
        .incoming: DisplayRepresentation(title: "Incoming"),
        .outgoing: DisplayRepresentation(title: "Outgoing"),
    ]
}

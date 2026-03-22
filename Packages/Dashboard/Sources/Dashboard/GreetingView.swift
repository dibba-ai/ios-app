import SwiftUI

struct GreetingView: View {
    let name: String?

    var body: some View {
        Text(greetingText)
            .font(.largeTitle)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greetingText: String {
        let greeting = timeBasedGreeting
        if let name, !name.isEmpty {
            return "\(greeting), \(name)"
        }
        return greeting
    }

    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5 ..< 11:
            return "Good morning"
        case 11 ..< 18:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }
}

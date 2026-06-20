import Foundation

enum LanguagePreference: String, CaseIterable, Identifiable {
  case auto
  case turkish
  case english

  var id: String { rawValue }

  var title: String {
    switch self {
    case .auto:
      return "Otomatik Algıla"
    case .turkish:
      return "Türkçe"
    case .english:
      return "İngilizce"
    }
  }

  var assistLanguageCode: String {
    switch self {
    case .auto:
      return "tr"
    case .turkish:
      return "tr"
    case .english:
      return "en"
    }
  }

  var deepgramLanguageCode: String? {
    switch self {
    case .auto:
      return nil
    case .turkish:
      return "tr"
    case .english:
      return "en"
    }
  }
}

enum AppConfig {
  static let authCallbackURL = URL(string: "milyonus://auth-callback")!

  static var apiBaseURL: URL? {
    urlValue(for: "API_BASE_URL")
  }

  static var supabaseURL: URL? {
    urlValue(for: "SUPABASE_URL")
  }

  static var supabaseAnonKey: String? {
    stringValue(for: "SUPABASE_ANON_KEY")
  }

  static func stringValue(for key: String) -> String? {
    guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
      return nil
    }

    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmed.isEmpty || trimmed.hasPrefix("$(") || trimmed.hasPrefix("BURAYA_") {
      return nil
    }

    return trimmed
  }

  static func urlValue(for key: String) -> URL? {
    guard let value = stringValue(for: key) else {
      return nil
    }

    return URL(string: value)
  }
}

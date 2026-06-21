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
  private static let productionAPIBaseURL = "https://milyonus-ai-nottaker-desktop-app-fo-five.vercel.app"

  static var apiBaseURL: URL? {
    urlValue(for: "API_BASE_URL", fallback: productionAPIBaseURL)
  }

  static var supabaseURL: URL? {
    urlValue(for: "SUPABASE_URL")
  }

  static var supabaseAnonKey: String? {
    stringValue(for: "SUPABASE_ANON_KEY")
  }

  static func stringValue(for key: String, fallback: String? = nil) -> String? {
    guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
      return fallback
    }

    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmed.isEmpty || trimmed.hasPrefix("$(") || trimmed.hasPrefix("BURAYA_") {
      return fallback
    }

    return trimmed
  }

  static func urlValue(for key: String, fallback: String? = nil) -> URL? {
    if let value = stringValue(for: key),
       let url = validURL(from: value) {
      return url
    }

    if let fallback {
      return validURL(from: fallback)
    }

    return nil
  }

  private static func validURL(from value: String) -> URL? {
    let normalizedValue: String
    if value.hasPrefix("http://") || value.hasPrefix("https://") {
      normalizedValue = value
    } else {
      normalizedValue = "https://\(value)"
    }

    guard let url = URL(string: normalizedValue),
          url.scheme != nil,
          url.host != nil else {
      return nil
    }

    return url
  }
}

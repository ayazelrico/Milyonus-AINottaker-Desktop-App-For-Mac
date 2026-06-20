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
  static var apiBaseURL: URL? {
    urlValue(for: "API_BASE_URL")
  }

  static var deepgramDevelopmentAPIKey: String? {
    stringValue(for: "DEEPGRAM_API_KEY")
  }

  static var mockSupabaseJWT: String? {
    stringValue(for: "MOCK_SUPABASE_JWT")
  }

  private static func stringValue(for key: String) -> String? {
    guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
      return nil
    }

    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmed.isEmpty || trimmed.hasPrefix("$(") {
      return nil
    }

    return trimmed
  }

  private static func urlValue(for key: String) -> URL? {
    guard let value = stringValue(for: key) else {
      return nil
    }

    return URL(string: value)
  }
}


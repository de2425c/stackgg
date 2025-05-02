import Foundation

// Type alias for clarity
typealias HandHistory = [String: Any]

enum HandParserError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(String)
    case decodingError(Error)
    
    var message: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return message
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

class HandParserService {
    static let shared = HandParserService()
    private let baseURL = "https://parserstack-81cfab5fcac9.herokuapp.com"
    
    func parseHand(description: String) async throws -> ParsedHandHistory {
        guard let url = URL(string: "\(baseURL)/parse-hand") else {
            throw HandParserError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["description": description]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Debug: Print received data
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Received JSON:", jsonString)
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HandParserError.invalidResponse
            }
            
            if httpResponse.statusCode == 400 {
                if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
                   let detail = errorResponse["detail"] {
                    throw HandParserError.serverError(detail)
                } else {
                    throw HandParserError.serverError("Bad Request")
                }
            }
            
            guard httpResponse.statusCode == 200 else {
                throw HandParserError.serverError("Server returned status code \(httpResponse.statusCode)")
            }
            
            // The server returns just the hand_history directly, so we need to wrap it
            let rawDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            // Create the expected structure
            let wrappedDict: [String: Any] = ["raw": rawDict ?? [:]]
            let wrappedData = try JSONSerialization.data(withJSONObject: wrappedDict)
            
            let decoder = JSONDecoder()
            do {
                return try decoder.decode(ParsedHandHistory.self, from: wrappedData)
            } catch {
                print("Decoding error:", error)
                throw HandParserError.decodingError(error)
            }
            
        } catch let error as HandParserError {
            throw error
        } catch {
            throw HandParserError.networkError(error)
        }
    }
} 

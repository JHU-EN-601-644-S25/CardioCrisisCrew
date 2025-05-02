import Foundation
import Combine

enum APIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case serverError(Int, String)
    case unauthorized
    case unknown
}

class AWSAPIService {
    private let baseURL = "https://qdiphk7654.execute-api.us-east-2.amazonaws.com/v3/"
    
    func postECGData(patientData: PatientData, ecgData: [Double]) -> AnyPublisher<Bool, APIError> {
        guard let url = URL(string: baseURL) else {
            return Fail(error: .invalidURL).eraseToAnyPublisher()
        }

        guard let token = UserDefaults.standard.string(forKey: "cognitoAccessToken") else {
            print("No access token found.")
            return Fail(error: .unauthorized).eraseToAnyPublisher()
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())

        let requestData = ECGDataRequest(
            patientData: patientData,
            ecgTimestamp: timestamp,
            ecgData: ecgData
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONEncoder().encode(requestData)
            if let body = String(data: request.httpBody!, encoding: .utf8) {
                print("Sending JSON: \(body)")
            }
        } catch {
            return Fail(error: .requestFailed(error)).eraseToAnyPublisher()
        }

        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { APIError.requestFailed($0) }
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                let statusCode = httpResponse.statusCode
                let responseBody = String(data: data, encoding: .utf8) ?? "<no body>"

                print("Status code: \(statusCode)")
                print("Response body: \(responseBody)")

                if (200...299).contains(statusCode) {
                    return true
                } else {
                    throw APIError.serverError(statusCode, responseBody)
                }
            }
            .mapError {
                if let apiError = $0 as? APIError {
                    return apiError
                } else {
                    return .unknown
                }
            }
            .eraseToAnyPublisher()
    }
}

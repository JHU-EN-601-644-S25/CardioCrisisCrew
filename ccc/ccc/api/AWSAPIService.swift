import Foundation
import Combine

enum APIError: Error {
    case invalidURL
    case unauthorized
    case requestFailed(Error)
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    case decodingFailed(Error)
    case unknown
}

/// Service to send ECG data to AWS API Gateway using Cognito JWT auth.
class AWSAPIService {
    static let shared = AWSAPIService()
    private let session: URLSession

    private var baseURLComponents: URLComponents {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "qdiphk7654.execute-api.us-east-2.amazonaws.com"
        components.path = "/v3" 
        return components
    }

    private init(session: URLSession = .shared) {
        self.session = session
    }

    /// Posts ECG data along with patient metadata. Requires a valid Cognito access token.
    func postECGData(patientData: PatientData, ecgData: [Double]) -> AnyPublisher<Bool, APIError> {
        // Build URL
        guard let url = baseURLComponents.url else {
            return Fail(error: .invalidURL).eraseToAnyPublisher()
        }

        // Fetch Cognito token
        guard let token = UserDefaults.standard.string(forKey: "cognitoIdToken"), !token.isEmpty else {
            print("No access ID found.")
            return Fail(error: .unauthorized).eraseToAnyPublisher()
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Encode JSON body
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let requestData = ECGDataRequest(
            patientData: patientData,
            ecgTimestamp: timestamp,
            ecgData: ecgData
        )
        do {
            let body = try JSONEncoder().encode(requestData)
            request.httpBody = body
            if let bodyString = String(data: body, encoding: .utf8) {
                print("Sending ECG data: \(bodyString)")
            }
        } catch {
            return Fail(error: .requestFailed(error)).eraseToAnyPublisher()
        }

        // Send network call
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.requestFailed($0) }
            .flatMap { data, response -> AnyPublisher<Bool, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: .invalidResponse).eraseToAnyPublisher()
                }
                let responseBody = String(data: data, encoding: .utf8) ?? "<empty>"
                print("Status code: \(httpResponse.statusCode)")
                print("Response body: \(responseBody)")

                if (200...299).contains(httpResponse.statusCode) {
                    return Just(true)
                        .setFailureType(to: APIError.self)
                        .eraseToAnyPublisher()
                }
                return Fail(error: .serverError(statusCode: httpResponse.statusCode, message: responseBody))
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}

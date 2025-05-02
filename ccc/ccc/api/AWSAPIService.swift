import Foundation
import Combine

enum APIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case serverError(Int, String)
    case unknown
}

class AWSAPIService {
    private let baseURL = "https://qdiphk7654.execute-api.us-east-2.amazonaws.com/v3/"
    
    // POST ECG data to AWS
    func postECGData(patientData: PatientData, ecgData: [Double]) -> AnyPublisher<Bool, APIError> {
        guard let url = URL(string: baseURL) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        // Create timestamp for current time
        let dateFormatter = ISO8601DateFormatter()
        let timestamp = dateFormatter.string(from: Date())
        
        // Create request body
        let requestData = ECGDataRequest(
            patientData: patientData,
            ecgTimestamp: timestamp,
            ecgData: ecgData
        )
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestData)
        } catch {
            return Fail(error: APIError.requestFailed(error)).eraseToAnyPublisher()
        }
        
        // Send request
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { APIError.requestFailed($0) }
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    return true
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw APIError.serverError(httpResponse.statusCode, errorMessage)
                }
            }
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                } else {
                    return APIError.unknown
                }
            }
            .eraseToAnyPublisher()
    }
} 

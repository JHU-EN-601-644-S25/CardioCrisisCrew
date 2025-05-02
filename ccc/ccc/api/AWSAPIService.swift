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
    
    // GET patient data from AWS
    func getPatientData(patientData: PatientData) -> AnyPublisher<PatientData, APIError> {
        // Build URL with query parameters
        var urlComponents = URLComponents(string: baseURL)
        if urlComponents == nil {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        // Add query parameters
        urlComponents?.queryItems = [
            URLQueryItem(name: "patient_id", value: patientData.patientId),
            URLQueryItem(name: "first_name", value: patientData.firstName),
            URLQueryItem(name: "last_name", value: patientData.lastName),
            URLQueryItem(name: "sex", value: patientData.sex),
            URLQueryItem(name: "age", value: String(patientData.age))
        ]
        
        guard let url = urlComponents?.url else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Send request (without a body)
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { APIError.requestFailed($0) }
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    return data
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw APIError.serverError(httpResponse.statusCode, errorMessage)
                }
            }
            .decode(type: PatientData.self, decoder: JSONDecoder())
            .mapError { error in
                if let decodingError = error as? DecodingError {
                    return APIError.decodingFailed(decodingError)
                } else if let apiError = error as? APIError {
                    return apiError
                } else {
                    return APIError.unknown
                }
            }
            .eraseToAnyPublisher()
    }
} 

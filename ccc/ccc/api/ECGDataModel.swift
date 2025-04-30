import Foundation

struct PatientData: Codable {
    let patientId: String
    let firstName: String
    let lastName: String
    let sex: String
    let age: Int

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case sex
        case age
    }
}

struct ECGData: Codable {
    let patientData: PatientData
    let ecgTimestamp: String
    let ecgData: [Int]

    enum CodingKeys: String, CodingKey {
        case patientData = "patient_data"
        case ecgTimestamp = "ecg_timestamp"
        case ecgData = "ecg_data"
    }
}

// For API requests
struct ECGDataRequest: Codable {
    let patientId: String
    let firstName: String
    let lastName: String
    let sex: String
    let age: Int
    let ecgTimestamp: String?
    let ecgData: [Double]?

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case sex
        case age
        case ecgTimestamp = "ecg_timestamp"
        case ecgData = "ecg_data"
    }

    init(patientData: PatientData, ecgTimestamp: String? = nil, ecgData: [Double]? = nil) {
        self.patientId = patientData.patientId
        self.firstName = patientData.firstName
        self.lastName = patientData.lastName
        self.sex = patientData.sex
        self.age = patientData.age
        self.ecgTimestamp = ecgTimestamp
        self.ecgData = ecgData
    }
}

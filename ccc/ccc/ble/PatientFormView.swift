import SwiftUI

// Form data structure
struct PatientFormData {
    var firstName: String = ""
    var lastName: String = ""
    var sex: String = "male"
    var age: String = ""
}

// Patient form view
struct PatientFormView: View {
    @Binding var patientInfo: PatientFormData
    @Binding var isPresented: Bool
    var onSubmit: (PatientData) -> Void
    
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Patient Information")) {
                    TextField("First Name", text: $patientInfo.firstName)
                        .autocapitalization(.words)
                    
                    TextField("Last Name", text: $patientInfo.lastName)
                        .autocapitalization(.words)
                    
                    Picker("Sex", selection: $patientInfo.sex) {
                        Text("Male").tag("male")
                        Text("Female").tag("female")
                        Text("Other").tag("other")
                    }
                    
                    TextField("Age", text: $patientInfo.age)
                        .keyboardType(.numberPad)
                }
                
                Section {
                    Button("Submit") {
                        if validateForm() {
                            let age = Int(patientInfo.age) ?? 0
                            
                            let patientData = PatientData(
                                patientId: "",  // This will be set by the parent view
                                firstName: patientInfo.firstName,
                                lastName: patientInfo.lastName,
                                sex: patientInfo.sex,
                                age: age
                            )
                            
                            onSubmit(patientData)
                            isPresented = false
                        } else {
                            showValidationAlert = true
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Patient Information")
            .navigationBarItems(
                trailing: Button("Cancel") {
                    isPresented = false
                }
            )
            .alert(isPresented: $showValidationAlert) {
                Alert(
                    title: Text("Validation Error"),
                    message: Text(validationMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func validateForm() -> Bool {
        if patientInfo.firstName.isEmpty {
            validationMessage = "First name is required"
            return false
        }
        
        // Only validate age if it's provided
        if !patientInfo.age.isEmpty && Int(patientInfo.age) == nil {
            validationMessage = "Age must be a number"
            return false
        }
        
        return true
    }
} 
import { API } from 'aws-amplify';

export const fetchECGReadings = async (patientId: string) => {
    try {
        const path = `/ecg/${patientId}`;
        const response = await API.get('ecgapi', path, {});
        return response;
    } catch (error) {
        console.error('Failed to fetch ECG data:', error);
        throw error;
    }
};
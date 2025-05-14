import React, { useEffect, useState } from 'react';
import { fetchECGReadings } from '../api/ECGService';

const Dashboard: React.FC = () => {
    const [readings, setReadings] = useState([]);

    useEffect(() => {
        fetchECGReadings('patient123').then(setReadings);
    }, []);

    return (
        <div>
            <h1>ECG Readings</h1>
            <pre>{JSON.stringify(readings, null, 2)}</pre>
        </div>
    );
};

export default Dashboard;

let chartInstance = null;

// Routing logic
document.querySelectorAll('.nav-link').forEach(link => {
    link.addEventListener('click', (e) => {
        e.preventDefault();
        // Update active link
        document.querySelectorAll('.nav-link').forEach(l => l.classList.remove('active'));
        e.target.classList.add('active');
        
        // Hide all views, show target view
        document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
        const targetId = e.target.getAttribute('data-target');
        document.getElementById(targetId).classList.add('active');
        
        // Load data based on view
        if (targetId === 'view-overview') fetchOverviewData();
        if (targetId === 'view-traffic') fetchTrafficLogs();
        if (targetId === 'view-abuse') fetchAbuseData();
        if (targetId === 'view-settings') fetchSettings();
    });
});

async function fetchOverviewData() {
    // KPIs
    const kpiRes = await fetch('/api/kpis');
    const kpis = await kpiRes.json();
    document.getElementById('kpiTotal').innerText = kpis.total_requests.toLocaleString();
    document.getElementById('kpiBlock').innerText = kpis.blocked_pct.toFixed(1) + '%';
    document.getElementById('kpiAvg').innerText = kpis.avg_response_time.toFixed(0) + ' ms';
    document.getElementById('kpiThreats').innerText = kpis.active_threats;

    // Traffic Chart
    const trafficRes = await fetch('/api/traffic');
    const trafficData = await trafficRes.json();
    
    const labels = [...new Set(trafficData.map(d => d.minute))];
    const allowed = labels.map(l => { const m = trafficData.find(d => d.minute === l && d.decision === 'allowed'); return m ? m.count : 0; });
    const blocked = labels.map(l => { const m = trafficData.find(d => d.minute === l && d.decision === 'blocked'); return m ? m.count : 0; });

    const ctx = document.getElementById('trafficChart').getContext('2d');
    if(chartInstance) chartInstance.destroy();
    
    chartInstance = new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [
                { 
                    label: 'Allowed', 
                    data: allowed, 
                    borderColor: '#A79F99', // Warm gray
                    backgroundColor: 'rgba(167, 159, 153, 0.15)', 
                    fill: true, 
                    tension: 0.4 
                },
                { 
                    label: 'Blocked', 
                    data: blocked, 
                    borderColor: '#5C3A2E', // Mocha brown
                    backgroundColor: 'rgba(92, 58, 46, 0.15)', 
                    fill: true, 
                    tension: 0.4 
                }
            ]
        },
        options: {
            responsive: true,
            scales: {
                x: { 
                    grid: { color: '#575453' }, 
                    ticks: { color: '#A79F99' } 
                },
                y: { 
                    grid: { color: '#575453' }, 
                    ticks: { color: '#A79F99' } 
                }
            },
            plugins: { legend: { labels: { color: '#D0C8C1', font: {family: 'Inter'} } } }
        }
    });
}

async function fetchTrafficLogs() {
    const res = await fetch('/api/logs');
    const logs = await res.json();
    const tbody = document.querySelector('#logsTable tbody');
    tbody.innerHTML = '';
    
    logs.slice(0, 50).forEach(log => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${log.timestamp}</td>
            <td>${log.ip_address}</td>
            <td>${log.endpoint}</td>
            <td>${log.status_code}</td>
            <td class="decision-${log.decision}">${log.decision.toUpperCase()}</td>
        `;
        tbody.appendChild(tr);
    });
}

async function fetchAbuseData() {
    const flagRes = await fetch('/api/flagged');
    const flags = await flagRes.json();
    const tbody = document.querySelector('#abuseTable tbody');
    tbody.innerHTML = '';
    
    if(flags.length === 0) {
        tbody.innerHTML = '<tr><td colspan="4" style="text-align:center">No active threats detected.</td></tr>';
    } else {
        flags.forEach(f => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td>${f.entity_value}</td>
                <td class="tier-${f.risk_tier}">${f.risk_tier}</td>
                <td>${f.abuse_score}</td>
                <td>${f.reason}</td>
            `;
            tbody.appendChild(tr);
        });
    }
}

async function fetchSettings() {
    const res = await fetch('/api/settings');
    const settings = await res.json();
    if(settings.length > 0) {
        document.getElementById('rpmInput').value = settings[0].threshold_value;
    }
}

document.getElementById('saveSettingsBtn').addEventListener('click', async () => {
    const rpm = document.getElementById('rpmInput').value;
    const btn = document.getElementById('saveSettingsBtn');
    btn.innerText = "Saving...";
    
    await fetch('/api/settings', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({rpm: rpm})
    });
    
    setTimeout(() => { btn.innerText = "Save Changes"; }, 1000);
});

document.getElementById('seedBtn').addEventListener('click', async () => {
    const btn = document.getElementById('seedBtn');
    btn.innerText = "Generating Traffic...";
    btn.disabled = true;
    
    await fetch('/api/seed', {method: 'POST'});
    
    btn.innerText = "Initialize & Seed Data";
    btn.disabled = false;
    
    fetchOverviewData();
});

document.getElementById('exportCsvBtn').addEventListener('click', () => {
    window.open('/api/export', '_blank');
});

document.getElementById('clearDbBtn').addEventListener('click', async () => {
    if(confirm("Are you sure you want to clear all data? This cannot be undone.")) {
        const btn = document.getElementById('clearDbBtn');
        btn.innerText = "Clearing...";
        await fetch('/api/clear', {method: 'POST'});
        btn.innerText = "Clear Database";
        fetchOverviewData();
        fetchTrafficLogs();
        fetchAbuseData();
        alert("Database cleared successfully!");
    }
});

// Initial load
fetchOverviewData();

// Execute after page load
document.addEventListener('DOMContentLoaded', () => {
  // Initialize all data
  fetchTotalClicks();
  fetchHourlyTrends();
  fetchTopLinks();
  fetchRecentLinks();
  
  // Set up auto-refresh (every 60 seconds)
  setInterval(() => {
    fetchTotalClicks();
    fetchHourlyTrends();
    fetchTopLinks();
    fetchRecentLinks();
  }, 60000);
});

// Get total clicks
async function fetchTotalClicks() {
  try {
    const response = await fetch('/api/stats/total-clicks');
    if (!response.ok) throw new Error('Network response was not ok');
    
    const data = await response.json();
    
    // Update UI
    document.getElementById('total-clicks').textContent = data.totalClicks.toLocaleString();
    document.getElementById('last-updated').textContent = `Last updated: ${new Date(data.timestamp).toLocaleString()}`;
  } catch (error) {
    console.error('Error fetching total clicks:', error);
    document.getElementById('total-clicks').textContent = 'Error loading data';
  }
}

// Get hourly trend data
let hourlyChart = null;
async function fetchHourlyTrends() {
  try {
    const response = await fetch('/api/stats/hourly-trends');
    if (!response.ok) throw new Error('Network response was not ok');
    
    const data = await response.json();
    
    // Destroy chart if it exists
    if (hourlyChart) {
      hourlyChart.destroy();
    }
    
    // Create new chart
    const ctx = document.getElementById('hourly-chart').getContext('2d');
    hourlyChart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: data.labels,
        datasets: [{
          label: 'Clicks per Hour',
          data: data.data,
          backgroundColor: 'rgba(54, 162, 235, 0.2)',
          borderColor: 'rgba(54, 162, 235, 1)',
          borderWidth: 2,
          tension: 0.4,
          fill: true
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              precision: 0
            }
          }
        },
        plugins: {
          legend: {
            display: false
          }
        }
      }
    });
  } catch (error) {
    console.error('Error fetching hourly trends:', error);
  }
}

// Get top short links
async function fetchTopLinks() {
  try {
    const response = await fetch('/api/stats/top-links');
    if (!response.ok) throw new Error('Network response was not ok');
    
    const data = await response.json();
    
    // Update table
    const tableBody = document.getElementById('top-links-table');
    
    if (data.length === 0) {
      tableBody.innerHTML = '<tr><td colspan="3" class="text-center">No data available</td></tr>';
      return;
    }
    
    tableBody.innerHTML = data.map(link => `
      <tr>
        <td><a href="${getShortUrl(link.short_code)}" target="_blank">${link.short_code}</a></td>
        <td><span class="text-truncate-custom" title="${link.original_url}">${link.original_url}</span></td>
        <td>${link.visit_count || 0}</td>
      </tr>
    `).join('');
  } catch (error) {
    console.error('Error fetching top links:', error);
    document.getElementById('top-links-table').innerHTML = '<tr><td colspan="3" class="text-center">Error loading data</td></tr>';
  }
}

// Get recently created short links
async function fetchRecentLinks() {
  try {
    const response = await fetch('/api/stats/recent-links');
    if (!response.ok) throw new Error('Network response was not ok');
    
    const data = await response.json();
    
    // Update table
    const tableBody = document.getElementById('recent-links-table');
    
    if (data.length === 0) {
      tableBody.innerHTML = '<tr><td colspan="3" class="text-center">No data available</td></tr>';
      return;
    }
    
    tableBody.innerHTML = data.map(link => `
      <tr>
        <td><a href="${getShortUrl(link.short_code)}" target="_blank">${link.short_code}</a></td>
        <td><span class="text-truncate-custom" title="${link.original_url}">${link.original_url}</span></td>
        <td>${link.created_at_formatted}</td>
      </tr>
    `).join('');
  } catch (error) {
    console.error('Error fetching recent links:', error);
    document.getElementById('recent-links-table').innerHTML = '<tr><td colspan="3" class="text-center">Error loading data</td></tr>';
  }
}

// Helper function: Get full short URL from short code
function getShortUrl(shortCode) {
  // In production, this should be retrieved from configuration
  return `/r/${shortCode}`;
}
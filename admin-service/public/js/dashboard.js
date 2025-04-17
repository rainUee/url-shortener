// 页面加载完成后执行
document.addEventListener('DOMContentLoaded', () => {
  // 初始化所有数据
  fetchTotalClicks();
  fetchHourlyTrends();
  fetchTopLinks();
  fetchRecentLinks();
  
  // 设置定时刷新 (每60秒刷新一次)
  setInterval(() => {
    fetchTotalClicks();
    fetchHourlyTrends();
    fetchTopLinks();
    fetchRecentLinks();
  }, 60000);
});

// 获取总点击数
async function fetchTotalClicks() {
  try {
    const response = await fetch('/api/stats/total-clicks');
    if (!response.ok) throw new Error('Network response was not ok');
    
    const data = await response.json();
    
    // 更新UI
    document.getElementById('total-clicks').textContent = data.totalClicks.toLocaleString();
    document.getElementById('last-updated').textContent = `最后更新: ${new Date(data.timestamp).toLocaleString()}`;
  } catch (error) {
    console.error('Error fetching total clicks:', error);
    document.getElementById('total-clicks').textContent = 'Error loading data';
  }
}

// 获取按小时的趋势数据
let hourlyChart = null;
async function fetchHourlyTrends() {
  try {
    const response = await fetch('/api/stats/hourly-trends');
    if (!response.ok) throw new Error('Network response was not ok');
    
    const data = await response.json();
    
    // 如果图表已存在则销毁
    if (hourlyChart) {
      hourlyChart.destroy();
    }
    
    // 创建新图表
    const ctx = document.getElementById('hourly-chart').getContext('2d');
    hourlyChart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: data.labels,
        datasets: [{
          label: '每小时点击数',
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

// 获取热门短链接
async function fetchTopLinks() {
  try {
    const response = await fetch('/api/stats/top-links');
    if (!response.ok) throw new Error('Network response was not ok');
    
    const data = await response.json();
    
    // 更新表格
    const tableBody = document.getElementById('top-links-table');
    
    if (data.length === 0) {
      tableBody.innerHTML = '<tr><td colspan="3" class="text-center">暂无数据</td></tr>';
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
    document.getElementById('top-links-table').innerHTML = '<tr><td colspan="3" class="text-center">加载数据时出错</td></tr>';
  }
}

// 获取最近创建的短链接
async function fetchRecentLinks() {
  try {
    const response = await fetch('/api/stats/recent-links');
    if (!response.ok) throw new Error('Network response was not ok');
    
    const data = await response.json();
    
    // 更新表格
    const tableBody = document.getElementById('recent-links-table');
    
    if (data.length === 0) {
      tableBody.innerHTML = '<tr><td colspan="3" class="text-center">暂无数据</td></tr>';
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
    document.getElementById('recent-links-table').innerHTML = '<tr><td colspan="3" class="text-center">加载数据时出错</td></tr>';
  }
}

// 辅助函数：根据短码获取完整短链接
function getShortUrl(shortCode) {
  // 实际环境中应该从配置中获取基础URL
  return `/r/${shortCode}`;
}
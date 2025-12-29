const fs = require("fs");
const path = require("path");

const CSV_PATH = path.join(
  __dirname,
  "../exported-csv/battlelog_consolidated.csv"
);
const OUTPUT_HTML = path.join(__dirname, "../analysis/analysis_report.html");

// CSV読み込み
function loadCSV(filePath) {
  const content = fs.readFileSync(filePath, "utf-8");
  const lines = content.trim().split("\n");
  const headers = lines[0].split(",");

  const data = [];
  for (let i = 1; i < lines.length; i++) {
    const values = lines[i].split(",");
    const obj = {};
    headers.forEach((h, idx) => {
      obj[h] = values[idx];
    });
    data.push(obj);
  }
  return data;
}

// 分析処理
function analyzeData(battles) {
  // 1. 全体統計
  const totalBattles = battles.length;
  const wins = battles.filter((b) => b.result === "WIN").length;
  const losses = battles.filter((b) => b.result === "LOSE").length;
  const winRate = ((wins / totalBattles) * 100).toFixed(1);

  // 2. キャラクター別勝率
  const charStats = {};
  battles.forEach((b) => {
    const char = b.my_character;
    if (!charStats[char]) {
      charStats[char] = { wins: 0, losses: 0, total: 0 };
    }
    charStats[char].total++;
    if (b.result === "WIN") charStats[char].wins++;
    else charStats[char].losses++;
  });

  const charWinRates = Object.entries(charStats)
    .map(([char, stats]) => ({
      character: char,
      winRate: ((stats.wins / stats.total) * 100).toFixed(1),
      wins: stats.wins,
      losses: stats.losses,
      total: stats.total,
    }))
    .sort((a, b) => b.winRate - a.winRate);

  // 3. 対戦相手別勝率
  const oppStats = {};
  battles.forEach((b) => {
    const opp = b.opp_character;
    if (!oppStats[opp]) {
      oppStats[opp] = { wins: 0, losses: 0, total: 0 };
    }
    oppStats[opp].total++;
    if (b.result === "WIN") oppStats[opp].wins++;
    else oppStats[opp].losses++;
  });

  const oppWinRates = Object.entries(oppStats)
    .map(([opp, stats]) => ({
      opponent: opp,
      winRate: ((stats.wins / stats.total) * 100).toFixed(1),
      wins: stats.wins,
      losses: stats.losses,
      total: stats.total,
    }))
    .sort((a, b) => b.total - a.total);

  // 4. ラウンド取得方法の統計
  const roundMethods = {
    perfect: 0,
    ca: 0,
    sa: 0,
    od: 0,
    chip: 0,
    victory: 0,
    normal: 0,
  };

  battles.forEach((b) => {
    try {
      const scores = JSON.parse(b.round_score);
      scores.forEach((s) => {
        const val = Math.abs(s);
        if (val === 8) roundMethods.perfect++;
        else if (val === 7) roundMethods.ca++;
        else if (val === 6) roundMethods.sa++;
        else if (val === 5) roundMethods.od++;
        else if (val === 2) roundMethods.chip++;
        else if (val === 1) roundMethods.victory++;
        else roundMethods.normal++;
      });
    } catch (e) {
      // スキップ
    }
  });

  // 5. 直近20戦の推移
  const recent20 = battles.slice(0, 20).reverse();
  const recentLabels = recent20.map((b, i) => `#${i + 1}`);
  const recentResults = recent20.map((b) => (b.result === "WIN" ? 1 : 0));

  // 6. MR推移（最大100戦）
  const mrData = battles
    .slice(0, 100)
    .reverse()
    .map((b, i) => ({
      x: i + 1,
      y: parseInt(b.my_mr) || 0,
    }));

  return {
    totalBattles,
    wins,
    losses,
    winRate,
    charWinRates,
    oppWinRates,
    roundMethods,
    recentLabels,
    recentResults,
    mrData,
  };
}

// HTML生成
function generateHTML(analysis) {
  const html = `<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SF6 Battle Analysis Report</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      padding: 20px;
      color: #333;
    }
    .container {
      max-width: 1400px;
      margin: 0 auto;
      background: white;
      border-radius: 20px;
      padding: 40px;
      box-shadow: 0 20px 60px rgba(0,0,0,0.3);
    }
    h1 {
      text-align: center;
      color: #667eea;
      margin-bottom: 10px;
      font-size: 2.5em;
      text-shadow: 2px 2px 4px rgba(0,0,0,0.1);
    }
    .subtitle {
      text-align: center;
      color: #888;
      margin-bottom: 40px;
      font-size: 1.1em;
    }
    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 20px;
      margin-bottom: 40px;
    }
    .stat-card {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 25px;
      border-radius: 15px;
      text-align: center;
      box-shadow: 0 5px 15px rgba(0,0,0,0.2);
      transition: transform 0.3s;
    }
    .stat-card:hover {
      transform: translateY(-5px);
    }
    .stat-value {
      font-size: 2.5em;
      font-weight: bold;
      margin: 10px 0;
    }
    .stat-label {
      font-size: 0.9em;
      opacity: 0.9;
      text-transform: uppercase;
      letter-spacing: 1px;
    }
    .charts-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(500px, 1fr));
      gap: 30px;
      margin-bottom: 40px;
    }
    .chart-container {
      background: #f8f9fa;
      padding: 25px;
      border-radius: 15px;
      box-shadow: 0 5px 15px rgba(0,0,0,0.1);
    }
    .chart-title {
      font-size: 1.3em;
      font-weight: bold;
      margin-bottom: 20px;
      color: #667eea;
    }
    canvas {
      max-height: 350px;
    }
    .table-container {
      background: #f8f9fa;
      padding: 25px;
      border-radius: 15px;
      box-shadow: 0 5px 15px rgba(0,0,0,0.1);
      margin-bottom: 30px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
    }
    th {
      background: #667eea;
      color: white;
      padding: 12px;
      text-align: left;
      font-weight: 600;
    }
    td {
      padding: 10px 12px;
      border-bottom: 1px solid #ddd;
    }
    tr:hover {
      background: #f0f0f0;
    }
    .win-rate-high { color: #28a745; font-weight: bold; }
    .win-rate-mid { color: #ffc107; font-weight: bold; }
    .win-rate-low { color: #dc3545; font-weight: bold; }
  </style>
</head>
<body>
  <div class="container">
    <h1>⚔️ SF6 Battle Analysis Report</h1>
    <p class="subtitle">Generated on ${new Date().toLocaleString("ja-JP")}</p>

    <div class="stats-grid">
      <div class="stat-card">
        <div class="stat-label">Total Battles</div>
        <div class="stat-value">${analysis.totalBattles}</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Wins</div>
        <div class="stat-value">${analysis.wins}</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Losses</div>
        <div class="stat-value">${analysis.losses}</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Win Rate</div>
        <div class="stat-value">${analysis.winRate}%</div>
      </div>
    </div>

    <div class="charts-grid">
      <div class="chart-container">
        <div class="chart-title">📊 Character Win Rate</div>
        <canvas id="charWinRateChart"></canvas>
      </div>
      <div class="chart-container">
        <div class="chart-title">🎯 Round Finish Methods</div>
        <canvas id="roundMethodsChart"></canvas>
      </div>
    </div>

    <div class="chart-container" style="margin-bottom: 30px;">
      <div class="chart-title">📈 Master Rating Progression (Last 100 Battles)</div>
      <canvas id="mrChart"></canvas>
    </div>

    <div class="chart-container" style="margin-bottom: 30px;">
      <div class="chart-title">🔥 Recent 20 Battles</div>
      <canvas id="recentChart"></canvas>
    </div>

    <div class="table-container">
      <div class="chart-title">🥊 VS Opponent Character Stats</div>
      <table>
        <thead>
          <tr>
            <th>Opponent</th>
            <th>Win Rate</th>
            <th>Wins</th>
            <th>Losses</th>
            <th>Total</th>
          </tr>
        </thead>
        <tbody>
          ${analysis.oppWinRates
            .map((o) => {
              const wrClass =
                o.winRate >= 60
                  ? "win-rate-high"
                  : o.winRate >= 40
                  ? "win-rate-mid"
                  : "win-rate-low";
              return `<tr>
              <td>${o.opponent}</td>
              <td class="${wrClass}">${o.winRate}%</td>
              <td>${o.wins}</td>
              <td>${o.losses}</td>
              <td>${o.total}</td>
            </tr>`;
            })
            .join("")}
        </tbody>
      </table>
    </div>

    <div class="table-container">
      <div class="chart-title">👤 Your Character Stats</div>
      <table>
        <thead>
          <tr>
            <th>Character</th>
            <th>Win Rate</th>
            <th>Wins</th>
            <th>Losses</th>
            <th>Total</th>
          </tr>
        </thead>
        <tbody>
          ${analysis.charWinRates
            .map((c) => {
              const wrClass =
                c.winRate >= 60
                  ? "win-rate-high"
                  : c.winRate >= 40
                  ? "win-rate-mid"
                  : "win-rate-low";
              return `<tr>
              <td>${c.character}</td>
              <td class="${wrClass}">${c.winRate}%</td>
              <td>${c.wins}</td>
              <td>${c.losses}</td>
              <td>${c.total}</td>
            </tr>`;
            })
            .join("")}
        </tbody>
      </table>
    </div>
  </div>

  <script>
    // Character Win Rate Chart
    new Chart(document.getElementById('charWinRateChart'), {
      type: 'bar',
      data: {
        labels: ${JSON.stringify(
          analysis.charWinRates.map((c) => c.character)
        )},
        datasets: [{
          label: 'Win Rate (%)',
          data: ${JSON.stringify(
            analysis.charWinRates.map((c) => parseFloat(c.winRate))
          )},
          backgroundColor: 'rgba(102, 126, 234, 0.8)',
          borderColor: 'rgba(102, 126, 234, 1)',
          borderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        scales: {
          y: { beginAtZero: true, max: 100 }
        }
      }
    });

    // Round Methods Chart
    new Chart(document.getElementById('roundMethodsChart'), {
      type: 'doughnut',
      data: {
        labels: ['Perfect', 'CA', 'SA', 'OD', 'Chip', 'Victory', 'Normal'],
        datasets: [{
          data: [
            ${analysis.roundMethods.perfect},
            ${analysis.roundMethods.ca},
            ${analysis.roundMethods.sa},
            ${analysis.roundMethods.od},
            ${analysis.roundMethods.chip},
            ${analysis.roundMethods.victory},
            ${analysis.roundMethods.normal}
          ],
          backgroundColor: [
            '#ff6384',
            '#36a2eb',
            '#ffce56',
            '#4bc0c0',
            '#9966ff',
            '#ff9f40',
            '#c9cbcf'
          ]
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: true
      }
    });

    // MR Progression Chart
    new Chart(document.getElementById('mrChart'), {
      type: 'line',
      data: {
        datasets: [{
          label: 'Master Rating',
          data: ${JSON.stringify(analysis.mrData)},
          borderColor: 'rgba(102, 126, 234, 1)',
          backgroundColor: 'rgba(102, 126, 234, 0.1)',
          tension: 0.3,
          fill: true
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        scales: {
          x: { type: 'linear', title: { display: true, text: 'Battle #' } },
          y: { title: { display: true, text: 'MR' } }
        }
      }
    });

    // Recent Battles Chart
    new Chart(document.getElementById('recentChart'), {
      type: 'bar',
      data: {
        labels: ${JSON.stringify(analysis.recentLabels)},
        datasets: [{
          label: 'Result',
          data: ${JSON.stringify(analysis.recentResults)},
          backgroundColor: ${JSON.stringify(
            analysis.recentResults.map((r) =>
              r === 1 ? "rgba(40, 167, 69, 0.8)" : "rgba(220, 53, 69, 0.8)"
            )
          )},
          borderColor: ${JSON.stringify(
            analysis.recentResults.map((r) =>
              r === 1 ? "rgba(40, 167, 69, 1)" : "rgba(220, 53, 69, 1)"
            )
          )},
          borderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        scales: {
          y: { 
            beginAtZero: true, 
            max: 1,
            ticks: {
              callback: function(value) {
                return value === 1 ? 'WIN' : 'LOSE';
              }
            }
          }
        }
      }
    });
  </script>
</body>
</html>`;

  return html;
}

// メイン処理
console.log("📊 SF6 Battle Analysis - HTML Report Generator");
console.log("=".repeat(50));

console.log(`📂 Loading CSV: ${CSV_PATH}`);
const battles = loadCSV(CSV_PATH);
console.log(`✓ Loaded ${battles.length} battles`);

console.log("🔍 Analyzing data...");
const analysis = analyzeData(battles);

console.log("📝 Generating HTML report...");
const html = generateHTML(analysis);

fs.writeFileSync(OUTPUT_HTML, html, "utf-8");
console.log(`✅ HTML report generated: ${OUTPUT_HTML}`);
console.log("\n💡 Open the file in your browser to view the analysis!");

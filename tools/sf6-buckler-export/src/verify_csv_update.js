/**
 * 統合CSVと新仕様CSVの整合性検証スクリプト
 */

const fs = require("fs");
const path = require("path");

function parseCSVLine(line) {
  const fields = [];
  let current = "";
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    const nextChar = line[i + 1];
    if (char === '"' && inQuotes && nextChar === '"') {
      current += '"';
      i++;
    } else if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === "," && !inQuotes) {
      fields.push(current);
      current = "";
    } else {
      current += char;
    }
  }
  fields.push(current);
  return fields;
}

function validateRoundScore(result, roundScore) {
  try {
    const scores = JSON.parse(roundScore);
    const wins = scores.filter((s) => s > 0).length;
    const losses = scores.filter((s) => s < 0).length;

    if (result === "WIN" && wins <= losses) return false;
    if (result === "LOSE" && losses <= wins) return false;
    return true;
  } catch {
    return false;
  }
}

const consolidatedFile = path.join(
  __dirname,
  "../exported-csv/battlelog_consolidated.csv"
);
const newSpecFile = path.join(
  __dirname,
  "../exported-csv/archived/battlelog_20251229_0234.csv"
);

console.log("統合CSVと新仕様CSVを比較検証します...\n");

// 新仕様CSVを読み込み
const newSpecContent = fs.readFileSync(newSpecFile, "utf-8");
const newSpecLines = newSpecContent.split("\n").filter((l) => l.trim());
const newSpecMap = new Map();

for (let i = 1; i < newSpecLines.length; i++) {
  const fields = parseCSVLine(newSpecLines[i]);
  const replayId = fields[8];
  const result = fields[6];
  const roundScore = fields[7];
  if (replayId) {
    newSpecMap.set(replayId, { result, roundScore });
  }
}

// 統合CSVを読み込み
const consolidatedContent = fs.readFileSync(consolidatedFile, "utf-8");
const consolidatedLines = consolidatedContent
  .split("\n")
  .filter((l) => l.trim());

let checked = 0;
let errors = [];

for (let i = 1; i < consolidatedLines.length; i++) {
  const fields = parseCSVLine(consolidatedLines[i]);
  const replayId = fields[8];
  const result = fields[6];
  const roundScore = fields[7];

  if (replayId && newSpecMap.has(replayId)) {
    checked++;
    const newData = newSpecMap.get(replayId);

    // result不一致チェック
    if (result !== newData.result) {
      errors.push({
        type: "result_mismatch",
        replayId,
        consolidated: { result, roundScore },
        newSpec: newData,
      });
    }

    // round_score不一致チェック
    if (roundScore !== newData.roundScore) {
      errors.push({
        type: "roundScore_mismatch",
        replayId,
        consolidated: { result, roundScore },
        newSpec: newData,
      });
    }

    // resultとround_scoreの論理整合性チェック
    if (!validateRoundScore(result, roundScore)) {
      errors.push({
        type: "logic_error",
        replayId,
        data: { result, roundScore },
        reason: "resultとround_scoreの勝敗数が矛盾",
      });
    }
  }
}

console.log("========================================");
console.log("統合CSV vs 新仕様CSV 検証結果");
console.log("========================================");
console.log(`チェック済みレコード数: ${checked}`);
console.log(`エラー件数: ${errors.length}`);
console.log("");

if (errors.length === 0) {
  console.log("✅ 問題なし！すべてのデータが正しく更新されています。");
  console.log("");
  console.log("確認項目:");
  console.log("  ✓ result（WIN/LOSE）の一致");
  console.log("  ✓ round_score（ラウンド結果配列）の一致");
  console.log("  ✓ resultとround_scoreの論理整合性");
} else {
  console.log("⚠️ 問題が見つかりました:");
  console.log("");
  errors.forEach((err, idx) => {
    console.log(`[${idx + 1}] ${err.type}: ${err.replayId}`);
    if (err.type === "result_mismatch") {
      console.log(`  統合CSV: result=${err.consolidated.result}`);
      console.log(`  新仕様CSV: result=${err.newSpec.result}`);
    } else if (err.type === "roundScore_mismatch") {
      console.log(`  統合CSV: round_score=${err.consolidated.roundScore}`);
      console.log(`  新仕様CSV: round_score=${err.newSpec.roundScore}`);
    } else if (err.type === "logic_error") {
      console.log(
        `  result=${err.data.result}, round_score=${err.data.roundScore}`
      );
      console.log(`  理由: ${err.reason}`);
    }
    console.log("");
  });
}

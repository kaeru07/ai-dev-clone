/**
 * 統合CSVを新仕様のround_scoreとresultで更新するスクリプト
 *
 * 使い方:
 *   node src/update_consolidated_with_new_spec.js
 */

const fs = require("fs");
const path = require("path");

const CONSOLIDATED_FILE = path.join(
  __dirname,
  "../exported-csv/battlelog_consolidated.csv"
);
const NEW_SPEC_FILE = path.join(
  __dirname,
  "../exported-csv/archived/battlelog_20251229_0234.csv"
);
const BACKUP_FILE = path.join(
  __dirname,
  "../exported-csv/battlelog_consolidated.csv.backup"
);

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

function escapeCSV(v) {
  const s = (v ?? "").toString();
  if (s.includes(",") || s.includes('"') || s.includes("\n")) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

function main() {
  console.log("統合CSVを新仕様で更新します...");

  // バックアップ作成
  console.log("1) バックアップ作成中...");
  fs.copyFileSync(CONSOLIDATED_FILE, BACKUP_FILE);
  console.log(`✓ バックアップ: ${BACKUP_FILE}`);

  // 新仕様CSVを読み込み（replay_id → { result, round_score } のマップ作成）
  console.log("2) 新仕様CSVを読み込み中...");
  const newSpecContent = fs.readFileSync(NEW_SPEC_FILE, "utf-8");
  const newSpecLines = newSpecContent.split("\n").filter((l) => l.trim());
  const newSpecMap = new Map();

  for (let i = 1; i < newSpecLines.length; i++) {
    const fields = parseCSVLine(newSpecLines[i]);
    const replayId = fields[8]; // replay_id
    const result = fields[6]; // result
    const roundScore = fields[7]; // round_score

    if (replayId) {
      newSpecMap.set(replayId, { result, roundScore });
    }
  }
  console.log(`✓ 新仕様データ ${newSpecMap.size} 件読み込み完了`);

  // 統合CSVを読み込み
  console.log("3) 統合CSVを読み込み中...");
  const consolidatedContent = fs.readFileSync(CONSOLIDATED_FILE, "utf-8");
  const consolidatedLines = consolidatedContent
    .split("\n")
    .filter((l) => l.trim());

  // 更新処理
  console.log("4) データ更新中...");
  const updatedLines = [consolidatedLines[0]]; // ヘッダー
  let updateCount = 0;

  for (let i = 1; i < consolidatedLines.length; i++) {
    const fields = parseCSVLine(consolidatedLines[i]);
    const replayId = fields[8]; // replay_id

    if (replayId && newSpecMap.has(replayId)) {
      const newData = newSpecMap.get(replayId);
      const oldResult = fields[6];
      const oldRoundScore = fields[7];

      // 更新
      fields[6] = newData.result;
      fields[7] = newData.roundScore;

      // 変更があった場合のみカウント
      if (
        oldResult !== newData.result ||
        oldRoundScore !== newData.roundScore
      ) {
        updateCount++;
        console.log(`  更新: ${replayId}`);
        console.log(
          `    旧: result=${oldResult}, round_score=${oldRoundScore}`
        );
        console.log(
          `    新: result=${newData.result}, round_score=${newData.roundScore}`
        );
      }
    }

    updatedLines.push(fields.map(escapeCSV).join(","));
  }

  // 書き込み
  console.log("5) 統合CSVに書き込み中...");
  fs.writeFileSync(CONSOLIDATED_FILE, updatedLines.join("\n"), "utf-8");
  console.log(`✓ 完了: ${updateCount} 件のデータを更新しました`);
  console.log(`✓ 出力: ${CONSOLIDATED_FILE}`);
  console.log(`\n元に戻す場合: copy "${BACKUP_FILE}" "${CONSOLIDATED_FILE}"`);
}

main();

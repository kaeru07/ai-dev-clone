/**
 * CSV統合スクリプト
 * - exported-csv内の全CSVファイルを統合
 * - replay_id + battle_time_jst で重複削除
 * - 日時順にソート
 * - battlelog_consolidated.csv として出力
 */

const fs = require("fs");
const path = require("path");

const CSV_DIR = path.join(__dirname, "../exported-csv");
const OUTPUT_FILE = path.join(CSV_DIR, "battlelog_consolidated.csv");
const ARCHIVE_DIR = path.join(CSV_DIR, "archived");
const ARCHIVE_DAYS = 30; // 保持日数

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

function readCSV(filePath) {
  let content = fs.readFileSync(filePath, "utf-8");
  // BOM（Byte Order Mark）を除去
  if (content.charCodeAt(0) === 0xfeff) {
    content = content.slice(1);
  }
  // 改行コードを正規化（CRLF/CR → LF）
  content = content.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
  const lines = content.split("\n").filter((l) => l.trim());

  if (lines.length === 0) return { header: null, rows: [] };

  const header = parseCSVLine(lines[0]);
  const rows = lines.slice(1).map((line) => {
    const fields = parseCSVLine(line);
    const row = {};
    header.forEach((col, i) => {
      row[col] = fields[i] || "";
    });
    // battle_time_jstの形式を統一（旧形式: YYYY-MM-DD-HH:MM:SS → 新形式: YYYY-MM-DD-HHMM）
    if (row["battle_time_jst"]) {
      row["battle_time_jst"] = row["battle_time_jst"].replace(
        /(\d{4}-\d{2}-\d{2})-(\d{2}):(\d{2})(:\d{2})?/,
        "$1-$2$3",
      );
    }
    // pageフィールドが空の場合は1をデフォルト値とする
    if (!row["page"] || row["page"].trim() === "") {
      row["page"] = "1";
    }
    return row;
  });

  return { header, rows };
}

function escapeCSV(value) {
  const str = String(value || "");
  if (str.includes(",") || str.includes('"') || str.includes("\n")) {
    return `"${str.replace(/"/g, '""')}"`;
  }
  return str;
}

function ensureDir(dir) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function deleteOldFiles(dir, days) {
  if (!fs.existsSync(dir)) return;

  const now = Date.now();
  const maxAge = days * 24 * 60 * 60 * 1000; // ミリ秒

  const files = fs.readdirSync(dir);
  let deletedCount = 0;

  files.forEach((file) => {
    const filePath = path.join(dir, file);
    const stats = fs.statSync(filePath);

    if (stats.isFile() && now - stats.mtimeMs > maxAge) {
      fs.unlinkSync(filePath);
      deletedCount++;
      console.log(`  [削除] ${file} (${days}日以上前)`);
    }
  });

  return deletedCount;
}

async function main() {
  console.log("====================================");
  console.log("CSV統合処理開始");
  console.log(`対象ディレクトリ: ${CSV_DIR}`);
  console.log("====================================\n");

  if (!fs.existsSync(CSV_DIR)) {
    console.error(`ERROR: ディレクトリが見つかりません: ${CSV_DIR}`);
    process.exit(1);
  }

  // アーカイブディレクトリ作成
  ensureDir(ARCHIVE_DIR);

  // 古いアーカイブファイルを削除
  console.log(`アーカイブディレクトリの古いファイルをチェック中...`);
  const deletedCount = deleteOldFiles(ARCHIVE_DIR, ARCHIVE_DAYS);
  if (deletedCount > 0) {
    console.log(`✓ ${deletedCount} 件の古いファイルを削除しました\n`);
  } else {
    console.log(`削除対象のファイルはありません\n`);
  }

  // CSVファイルを取得（consolidated以外）
  const files = fs
    .readdirSync(CSV_DIR)
    .filter((f) => f.endsWith(".csv") && !f.includes("consolidated"))
    .map((f) => path.join(CSV_DIR, f));

  if (files.length === 0) {
    console.log("統合するCSVファイルが見つかりませんでした。");
    process.exit(0);
  }

  console.log(`対象ファイル数: ${files.length}`);

  // 全データを読み込み
  const allData = new Map(); // key: replay_id + battle_time_jst
  let header = null;

  // 既存の統合CSVがあれば先に読み込む
  if (fs.existsSync(OUTPUT_FILE)) {
    console.log(`\n既存の統合CSVを読み込み中: ${path.basename(OUTPUT_FILE)}`);
    const { header: h, rows } = readCSV(OUTPUT_FILE);
    if (h) {
      header = h;
    }
    rows.forEach((row) => {
      const replayId = row["replay_id"] || "";
      const battleTime = row["battle_time_jst"] || "";
      const key = `${replayId}_${battleTime}`;
      allData.set(key, row);
    });
    console.log(`  既存データ: ${rows.length} 件`);
  }

  // 既存の統合CSVがあれば先に読み込む
  if (fs.existsSync(OUTPUT_FILE)) {
    console.log(`\n既存の統合CSVを読み込み中: ${path.basename(OUTPUT_FILE)}`);
    const { header: h, rows } = readCSV(OUTPUT_FILE);
    if (h) {
      header = h;
    }
    rows.forEach((row) => {
      const replayId = row["replay_id"] || "";
      const battleTime = row["battle_time_jst"] || "";
      const key = `${replayId}_${battleTime}`;
      allData.set(key, row);
    });
    console.log(`  既存データ: ${rows.length} 件`);
  }

  // 新しいCSVファイルを読み込んで追加
  console.log(`\n新規CSVファイルを読み込み中...`);
  files.forEach((file, idx) => {
    console.log(`[${idx + 1}/${files.length}] ${path.basename(file)}`);
    const { header: h, rows } = readCSV(file);

    if (!header && h) {
      header = h;
    }

    let addedCount = 0;
    rows.forEach((row) => {
      const replayId = row["replay_id"] || "";
      const battleTime = row["battle_time_jst"] || "";
      const key = `${replayId}_${battleTime}`;

      // 重複チェック：新しいデータのみ追加
      if (!allData.has(key)) {
        allData.set(key, row);
        addedCount++;
      }
    });
    console.log(`  → 新規追加: ${addedCount} 件`);
  });

  console.log(`\n読み込み完了: ${allData.size} 件のユニークなデータ`);

  // データを配列に変換してソート（日時順）
  const sortedData = Array.from(allData.values()).sort((a, b) => {
    const timeA = a["battle_time_jst"] || "";
    const timeB = b["battle_time_jst"] || "";
    return timeB.localeCompare(timeA); // 降順（新しい順）
  });

  // CSV出力
  const outputLines = [];

  // ヘッダー
  if (header) {
    outputLines.push(header.join(","));
  }

  // データ行
  sortedData.forEach((row) => {
    const line = header.map((col) => escapeCSV(row[col] || "")).join(",");
    outputLines.push(line);
  });

  // 改行コードをLF（Unix形式）に統一してファイル出力
  const csvContent = outputLines.join("\n");
  fs.writeFileSync(OUTPUT_FILE, csvContent, "utf-8");

  console.log("====================================");
  console.log(`✓ 統合完了: ${OUTPUT_FILE}`);
  console.log(`  総データ数: ${sortedData.length} 件`);
  console.log(`  改行コード: LF (Unix形式)`);
  console.log("====================================\n");

  // 元ファイルをアーカイブに移動
  console.log("元ファイルをアーカイブに移動中...");
  let movedCount = 0;
  files.forEach((file) => {
    const fileName = path.basename(file);
    const archivePath = path.join(ARCHIVE_DIR, fileName);

    try {
      fs.renameSync(file, archivePath);
      movedCount++;
    } catch (e) {
      console.warn(`  [警告] 移動失敗: ${fileName} - ${e.message}`);
    }
  });

  console.log(`✓ ${movedCount} 件のファイルをアーカイブしました`);
  console.log(`  アーカイブ先: ${ARCHIVE_DIR}`);
}

main().catch((e) => {
  console.error("エラー:", e);
  process.exit(1);
});

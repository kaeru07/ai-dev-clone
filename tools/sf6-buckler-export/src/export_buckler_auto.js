/**
 * SF6 Buckler's Boot Camp battlelog exporter (Ranked) - Auto Loop Version
 * - Scrapes pages 1..10 of /battlelog/rank
 * - Reads __NEXT_DATA__ JSON from each page
 * - Exports CSV to: C:\ai-script\tools\sf6-buckler-export\exported-csv\battlelog_yyyymmddhhmmss.csv
 * - 自動ループ：150分ごとにスクレイピング実行
 * - セッション維持：60分ごとにページアクセス
 *
 * Prereq:
 *   npm i playwright
 *   npx playwright install
 */

const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");
const { execSync } = require("child_process");

// ====== SETTINGS ======
const SID = "3133570759"; // ←あなたのsid（URLの /profile/{sid}/ に入ってる数値）※初回起動時に自動設定されます
const TOTAL_PAGES = 10;
const SCRAPE_INTERVAL = 150; // 分（スクレイピング間隔）
const KEEP_ALIVE_INTERVAL = 60; // 分（セッション延命のページアクセス間隔）
const SESSION_FILE = path.join(__dirname, "buckler-session.json");

const BASE_URL = `https://www.streetfighter.com/6/buckler/ja-jp/profile/${SID}/battlelog/rank`;
const OUTPUT_DIR = path.join(__dirname, "../exported-csv");

function pad2(n) {
  return String(n).padStart(2, "0");
}
function nowStamp() {
  const d = new Date();
  const y = d.getFullYear();
  const mo = pad2(d.getMonth() + 1);
  const da = pad2(d.getDate());
  const hh = pad2(d.getHours());
  const mm = pad2(d.getMinutes());
  return `${y}${mo}${da}_${hh}${mm}`;
}
function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function formatBattleTime(isoWithTZ) {
  if (!isoWithTZ) return "";
  const core = String(isoWithTZ).slice(0, 19);
  // フォーマット: YYYY-MM-DD-HHMM (コロンと秒を除去)
  return core.replace("T", "-").replace(/:(\d{2}):(\d{2})$/, "$1");
}

function _classifyRoundCode(v) {
  // ラウンド結果コード:
  // 8=P (Perfect), 7=CA (Critical Art), 6=SA (Super Art),
  // 5=OD (Overdrive), 2=C (Chip), 1=V (Victory)
  // 0=負け, それ以外は勝ち
  if (v === 0) return "L";
  if (v === 1 || v === 2 || v === 5 || v === 6 || v === 7 || v === 8)
    return "W";
  return "U";
}

function decideResultAndScore(myRR, oppRR) {
  const my = Array.isArray(myRR) ? myRR : [];
  const opp = Array.isArray(oppRR) ? oppRR : [];
  const maxLen = Math.max(my.length, opp.length);

  let myWin = 0;
  let oppWin = 0;
  let unknown = 0;

  for (let i = 0; i < maxLen; i++) {
    const mc = _classifyRoundCode(my[i]);
    const oc = _classifyRoundCode(opp[i]);

    if (mc === "W" && oc !== "W") myWin++;
    else if (oc === "W" && mc !== "W") oppWin++;
    else if (mc === "L" && oc !== "L") oppWin++;
    else if (oc === "L" && mc !== "L") myWin++;
    else unknown++;
  }

  const score = `${myWin}-${oppWin}`;
  let result = "UNKNOWN";
  let finalScore = score;

  if (myWin > oppWin) {
    result = "WIN";
    finalScore = `${myWin}-${oppWin}`;
  } else if (myWin < oppWin) {
    result = "LOSE";
    finalScore = `${myWin}-${oppWin}`;
  } else {
    result = "LOSE";
    finalScore = `${myWin}-${oppWin + 1}`;
  }

  return {
    result,
    round_score: finalScore,
    debug: { my_raw: my, opp_raw: opp, myWin, oppWin, unknown },
  };
}

function csvEscape(v) {
  const s = (v ?? "").toString();
  if (s.includes(",") || s.includes('"') || s.includes("\n")) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForEnter() {
  process.stdin.resume();
  return new Promise((resolve) => {
    process.stdin.once("data", () => resolve());
  });
}

async function getNextData(page) {
  return await page.evaluate(() => {
    const el = document.getElementById("__NEXT_DATA__");
    if (!el) return null;
    try {
      return JSON.parse(el.textContent);
    } catch {
      return null;
    }
  });
}

function extractMyIdentity(nextData) {
  const pp = nextData?.props?.pageProps;
  const banner = pp?.fighter_banner_info;

  const myShortId = banner?.personal_info?.short_id;
  const myFighterId = banner?.personal_info?.fighter_id;

  return { myShortId, myFighterId };
}

function pickSides(replay, myShortId, myFighterId) {
  const p1 = replay?.player1_info;
  const p2 = replay?.player2_info;

  const p1Short = p1?.player?.short_id;
  const p2Short = p2?.player?.short_id;
  const p1Fid = p1?.player?.fighter_id;
  const p2Fid = p2?.player?.fighter_id;

  const isMe1 =
    (myShortId != null && p1Short === myShortId) ||
    (myFighterId && p1Fid === myFighterId);
  const isMe2 =
    (myShortId != null && p2Short === myShortId) ||
    (myFighterId && p2Fid === myFighterId);

  if (isMe1 && !isMe2) return { me: p1, opp: p2, meSide: 1 };
  if (isMe2 && !isMe1) return { me: p2, opp: p1, meSide: 2 };

  return { me: p1, opp: p2, meSide: 1 };
}

async function consolidateCSV() {
  console.log("\n====================================");
  console.log("CSV統合処理を開始します...");
  console.log("====================================");
  try {
    const consolidateScript = path.join(__dirname, "consolidate_csv.js");
    execSync(`node "${consolidateScript}"`, {
      stdio: "inherit",
      cwd: __dirname,
    });
    console.log("✓ CSV統合完了");
  } catch (e) {
    console.error("⚠ CSV統合でエラー発生:", e.message);
  }
}

async function main() {
  ensureDir(OUTPUT_DIR);

  const browser = await chromium.launch({
    headless: false,
  });

  let context;
  if (fs.existsSync(SESSION_FILE)) {
    console.log(`セッションファイル検出: ${SESSION_FILE}`);
    try {
      context = await browser.newContext({ storageState: SESSION_FILE });
      console.log("✓ セッション復元成功");
    } catch (e) {
      console.log("⚠ セッション復元失敗、新規作成します");
      context = await browser.newContext();
    }
  } else {
    context = await browser.newContext();
  }

  const page = await context.newPage();
  let isFirstRun = true;

  // Ctrl+C でのプログラム終了処理
  let isShuttingDown = false;
  process.on("SIGINT", async () => {
    if (isShuttingDown) return;
    isShuttingDown = true;
    console.log("\n\n⚠ プログラムを停止します...");
    if (keepAliveTimer) {
      clearInterval(keepAliveTimer);
    }
    await browser.close();
    console.log("✓ 終了しました。");
    process.exit(0);
  });

  let keepAliveTimer = null;
  function startKeepAlive() {
    if (keepAliveTimer) clearInterval(keepAliveTimer);
    keepAliveTimer = setInterval(
      async () => {
        try {
          console.log(`[KeepAlive] ページアクセスしてセッション延命中...`);
          await page.goto(`${BASE_URL}?page=1`, {
            waitUntil: "domcontentloaded",
          });
        } catch (e) {
          console.error("[KeepAlive] エラー:", e.message);
        }
      },
      KEEP_ALIVE_INTERVAL * 60 * 1000,
    );
  }

  console.log("====================================");
  console.log("自動スクレイピングループ開始");
  console.log(`- スクレイピング間隔: ${SCRAPE_INTERVAL}分`);
  console.log(`- セッション延命: ${KEEP_ALIVE_INTERVAL}分ごと`);
  console.log("- 停止: Ctrl+C");
  console.log("====================================");

  let loopCount = 0;
  while (true) {
    loopCount++;
    console.log(`\n========== Loop ${loopCount} ==========`);

    try {
      if (isFirstRun) {
        console.log("1) ブラウザで Buckler にログイン");
        console.log("2) バトルログ(ランクマ)が見える状態にする");
        console.log("準備できたら Enter を押してください");
        await page.goto(`${BASE_URL}?page=1`, {
          waitUntil: "domcontentloaded",
        });
        await waitForEnter();
        isFirstRun = false;

        await context.storageState({ path: SESSION_FILE });
        console.log(`✓ セッション保存: ${SESSION_FILE}`);
      }

      await page.goto(`${BASE_URL}?page=1`, { waitUntil: "domcontentloaded" });
      let next1 = await getNextData(page);

      if (!next1) {
        console.error(
          "⚠️ __NEXT_DATA__ が取れません。ログイン切れの可能性があります。",
        );
        process.stdout.write("\x07");
        console.log("ブラウザで再ログインして Enter を押してください...");
        await waitForEnter();

        await context.storageState({ path: SESSION_FILE });
        console.log(`✓ セッション再保存: ${SESSION_FILE}`);

        await page.goto(`${BASE_URL}?page=1`, {
          waitUntil: "domcontentloaded",
        });
        next1 = await getNextData(page);
        if (!next1) {
          console.error(
            "ERROR: 再試行しても __NEXT_DATA__ が取れません。次のループへスキップします。",
          );
          await sleep(SCRAPE_INTERVAL * 60 * 1000);
          continue;
        }
      }

      const { myShortId, myFighterId } = extractMyIdentity(next1);
      console.log("My identity:", { myShortId, myFighterId });

      const outPath = path.join(OUTPUT_DIR, `battlelog_${nowStamp()}.csv`);
      const header = [
        "battle_time_jst",
        "battle_type",
        "my_character",
        "opp_character",
        "my_mr",
        "opp_mr",
        "result",
        "round_score",
        "replay_id",
        "page",
      ].join(",");

      const rows = [header];

      for (let p = 1; p <= TOTAL_PAGES; p++) {
        const url = `${BASE_URL}?page=${p}`;
        console.log(`Fetching page ${p}/${TOTAL_PAGES}: ${url}`);

        await page.goto(url, { waitUntil: "domcontentloaded" });

        const nd = await getNextData(page);
        const replayList = nd?.props?.pageProps?.replay_list;

        if (!Array.isArray(replayList) || replayList.length === 0) {
          console.log("  replay_list が空。スキップします。");
          continue;
        }

        for (const r of replayList) {
          const { me, opp } = pickSides(r, myShortId, myFighterId);

          const battleType =
            r?.replay_battle_type_name || r?.replay_battle_type || "";
          const myChar =
            me?.playing_character_tool_name || me?.character_tool_name || "";
          const oppChar =
            opp?.playing_character_tool_name || opp?.character_tool_name || "";

          const myMr = me?.master_rating ?? "";
          const oppMr = opp?.master_rating ?? "";

          // MRが0のデータをスキップ
          if (myMr === 0 || oppMr === 0) {
            continue;
          }

          let isoJst = "";
          if (typeof r?.uploaded_at === "number") {
            const d = new Date(r.uploaded_at * 1000);
            const j = new Date(d.getTime() + 9 * 60 * 60 * 1000);
            const y = j.getUTCFullYear();
            const mo = pad2(j.getUTCMonth() + 1);
            const da = pad2(j.getUTCDate());
            const hh = pad2(j.getUTCHours());
            const mm = pad2(j.getUTCMinutes());
            isoJst = `${y}-${mo}-${da}-${hh}${mm}`;
          }

          const battleTime = formatBattleTime(isoJst);

          const myRR = me?.round_results || [];
          const oppRR = opp?.round_results || [];

          const { result } = decideResultAndScore(myRR, oppRR);

          // 改良版: 負けたラウンドは相手のコードをマイナスで記録
          const enhancedRR = myRR.map((myCode, index) => {
            if (myCode === 0 && oppRR[index] !== undefined) {
              return -oppRR[index]; // 負けた場合は相手のコードをマイナスに
            }
            return myCode; // 勝った場合はそのまま
          });

          const myRoundResults = JSON.stringify(enhancedRR);

          const replayId = r?.replay_id || "";

          const line = [
            battleTime,
            battleType,
            myChar,
            oppChar,
            myMr,
            oppMr,
            result,
            myRoundResults,
            replayId,
            String(p),
          ]
            .map(csvEscape)
            .join(",");

          rows.push(line);
        }
      }

      fs.writeFileSync(outPath, rows.join("\n"), "utf-8");
      console.log(`✓ Done: ${outPath}`);

      await context.storageState({ path: SESSION_FILE });
      console.log(`✓ セッション更新: ${SESSION_FILE}`);

      // スクレイピング完了後に統合CSVを作成
      await consolidateCSV();

      console.log(
        `\n次のスクレイピングまで ${SCRAPE_INTERVAL}分 待機します...`,
      );
      console.log(
        `(セッション延命: ${KEEP_ALIVE_INTERVAL}分ごとにページアクセス)`,
      );

      startKeepAlive();
      await sleep(SCRAPE_INTERVAL * 60 * 1000);

      if (keepAliveTimer) {
        clearInterval(keepAliveTimer);
        keepAliveTimer = null;
      }
    } catch (e) {
      console.error(`\n❌ Loop ${loopCount} でエラー発生:`, e.message);
      console.error("スタックトレース:", e.stack);
      console.log(`${SCRAPE_INTERVAL}分後に再試行します...`);

      startKeepAlive();
      await sleep(SCRAPE_INTERVAL * 60 * 1000);
      if (keepAliveTimer) {
        clearInterval(keepAliveTimer);
        keepAliveTimer = null;
      }
    }
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

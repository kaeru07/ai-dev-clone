/**
 * SF6 Buckler's Boot Camp battlelog exporter (Ranked)
 * - Scrapes pages 1..10 of /battlelog/rank
 * - Reads __NEXT_DATA__ JSON from each page
 * - Exports CSV to: C:\ai-script\tools\sf6-buckler-export\exported-csv\battlelog_yyyymmddhhmmss.csv
 *
 * Prereq:
 *   npm i playwright
 *   npx playwright install
 */

const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

// ====== SETTINGS ======
const SID = "1146188535"; // ←あなたのsid（URLの /profile/{sid}/ に入ってる数値）※初回起動時に自動設定されます
const TOTAL_PAGES = 10;
const SCRAPE_INTERVAL = 150; // 分（スクレイピング間隔）
const KEEP_ALIVE_INTERVAL = 60; // 分（セッション延命のページアクセス間隔）
const SESSION_FILE = path.join(__dirname, "buckler-session.json");

// 対戦種別URLパス
const MATCH_TYPE_PATHS = {
  rank:        { path: "rank",         label: "ランクマッチ",   hasMR: true  },
  casual:      { path: "casual_match", label: "カジュアルマッチ", hasMR: false },
  custom:      { path: "custom_match", label: "カスタムマッチ",  hasMR: false },
  battle_hub:  { path: "hub",          label: "バトルハブ",      hasMR: false },
};

const BASE_PROFILE_URL = `https://www.streetfighter.com/6/buckler/ja-jp/profile/${SID}/battlelog`;
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
  const ss = pad2(d.getSeconds());
  // yyyymmddhhmmss
  return `${y}${mo}${da}_${hh}${mm}`;
}
function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

/**
 * ISO(例: 2025-12-18T02:56:48+09:00) -> 2025-12-18-02:56:48
 * 文字列として整形（JSTのまま見せたい用途向け）
 */
function formatBattleTime(isoWithTZ) {
  if (!isoWithTZ) return "";
  // 2025-12-18T02:56:48+09:00 -> 2025-12-18T02:56:48
  const core = String(isoWithTZ).slice(0, 19);
  return core.replace("T", "-");
}

/**
 * round_results の値が 0/1 だけじゃない試合があるので耐性を持たせる
 * 目安:
  8=P　パーフェクト勝ち
  7=CA　CAで勝ち
  6=SA　SAで勝ち
  5=OD　ODで勝ち
  2=C　　削り勝ち
  1=V　通常勝ち
  0=L　通常負け */
// countRoundWins removed: use decideResultAndScore() only

function _classifyRoundCode(v) {
  // Observed codes in Buckler __NEXT_DATA__. These can vary by match/end condition.
  // We classify "win/lose" broadly, then decide per-round by comparing both sides.
  // Win-like: 1,5,6,8 / Lose-like: 0,7 / Others: unknown
  if (v === 1 || v === 5 || v === 6 || v === 8) return "W";
  if (v === 0 || v === 7) return "L";
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

    // Decide winner of each round by comparing both sides.
    if (mc === "W" && oc !== "W") myWin++;
    else if (oc === "W" && mc !== "W") oppWin++;
    else if (mc === "L" && oc !== "L") oppWin++; // fallback
    else if (oc === "L" && mc !== "L") myWin++; // fallback
    else unknown++;
  }
  // 勝利数字パターン
  /*
  8=P
  7=CA
  6=SA
  5=OD
  2=C
  1=V
  */

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
    // ★ここがCA負けを救う唯一の方法
    // ランクマは必ず決着がつく（DRAWは存在しない）
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
  // __NEXT_DATA__ の中身をJSONとして取得
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

  // 通常はどっちかがtrue
  if (isMe1 && !isMe2) return { me: p1, opp: p2, meSide: 1 };
  if (isMe2 && !isMe1) return { me: p2, opp: p1, meSide: 2 };

  // どっちも判定できない場合はとりあえず1P=me扱い（保険）
  return { me: p1, opp: p2, meSide: 1 };
}

async function selectMatchType() {
  const keys = Object.keys(MATCH_TYPE_PATHS);
  console.log("====================================");
  console.log("取得する対戦種別を選んでください:");
  keys.forEach((k, i) => {
    console.log(`  ${i + 1}) ${MATCH_TYPE_PATHS[k].label}`);
  });
  console.log("番号を入力して Enter (デフォルト: 1=ランクマッチ):");
  console.log("====================================");

  return new Promise((resolve) => {
    process.stdin.resume();
    process.stdin.once("data", (d) => {
      process.stdin.pause();
      const n = parseInt(d.toString().trim(), 10);
      const key = (n >= 1 && n <= keys.length) ? keys[n - 1] : "rank";
      console.log(`✓ 選択: ${MATCH_TYPE_PATHS[key].label}`);
      resolve(key);
    });
  });
}

async function main() {
  ensureDir(OUTPUT_DIR);

  // 対戦種別を選択
  const matchTypeKey = process.argv[2] || await selectMatchType();
  const matchTypeDef = MATCH_TYPE_PATHS[matchTypeKey] || MATCH_TYPE_PATHS["rank"];
  const BASE_URL = `${BASE_PROFILE_URL}/${matchTypeDef.path}`;

  // Edgeで動かしたい場合：channel: "msedge" を使う
  // ただし環境によっては未対応なので、まずはchromium標準でOK
  const browser = await chromium.launch({
    headless: false,
    // channel: "msedge", // ←Edgeでやりたいならコメント解除
  });

  const context = await browser.newContext();
  const page = await context.newPage();

  console.log("====================================");
  console.log(`1) ブラウザで Buckler にログイン`);
  console.log(`2) バトルログ(${matchTypeDef.label})が見える状態にする`);
  console.log("準備できたら Enter を押してください");
  console.log("====================================");

  await page.goto(`${BASE_URL}?page=1`, { waitUntil: "domcontentloaded" });
  await waitForEnter();

  // 1ページ目から自分の short_id / fighter_id を取得して “自分側” 判定に使う
  let next1 = await getNextData(page);
  if (!next1) {
    console.error(
      "ERROR: __NEXT_DATA__ が取れません。ログイン状態/ページを確認してください。"
    );
    await browser.close();
    process.exit(1);
  }
  const { myShortId, myFighterId } = extractMyIdentity(next1);
  console.log("My identity:", { myShortId, myFighterId });

  const header = [
    "battle_time_jst",
    "battle_type",
    "match_type",
    "my_character",
    "opp_character",
    "my_mr",
    "opp_mr",
    "result",
    "round_score",
    "replay_id",
    "page",
    "my_short_id",
  ].join(",");

  const rows = [header];

  for (let p = 1; p <= TOTAL_PAGES; p++) {
    const url = `${BASE_URL}?page=${p}`;
    console.log(`Fetching page ${p}/${TOTAL_PAGES}: ${url}`);

    await page.goto(url, { waitUntil: "domcontentloaded" });

    const nd = await getNextData(page);
    const replayList = nd?.props?.pageProps?.replay_list;

    if (!Array.isArray(replayList) || replayList.length === 0) {
      console.log(
        "  replay_list が空。ページが正しいか/ログイン切れを確認して。"
      );
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

      // ランクマのみMR=0スキップ（カジュアル等はMR不要）
      if (matchTypeDef.hasMR && (myMr === 0 || oppMr === 0)) {
        continue;
      }

      // ★時間：まず uploaded_at（epoch秒）をJST ISO化してから整形
      // （NextDataに battle_at / played_at があるならそっち優先に差し替え可能）
      let isoJst = "";
      if (typeof r?.uploaded_at === "number") {
        // epoch秒 -> Date(ms)
        const d = new Date(r.uploaded_at * 1000);
        // JSTとして文字列化（+09:00固定にしたいので手作り）
        const j = new Date(d.getTime() + 9 * 60 * 60 * 1000);
        const y = j.getUTCFullYear();
        const mo = pad2(j.getUTCMonth() + 1);
        const da = pad2(j.getUTCDate());
        const hh = pad2(j.getUTCHours());
        const mm = pad2(j.getUTCMinutes());
        const ss = pad2(j.getUTCSeconds());
        // isoJst = `${y}-${mo}-${da}T${hh}:${mm}:${ss}+09:00`;
        isoJst = `${y}-${mo}-${da}-${hh}${mm}`;
      }

      const battleTime = formatBattleTime(isoJst);

      // ★勝敗/スコア：round_results を “コード混在” 前提で判定
      const myRR = me?.round_results || [];
      const oppRR = opp?.round_results || [];

      const { result, round_score } = decideResultAndScore(myRR, oppRR);

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
        matchTypeKey,
        myChar,
        oppChar,
        myMr,
        oppMr,
        result,
        myRoundResults,
        replayId,
        String(p),
        myShortId || "",
      ]
        .map(csvEscape)
        .join(",");

      rows.push(line);
    }
  }

  fs.writeFileSync(outPath, rows.join("\n"), "utf-8");
  console.log(`Done: ${outPath}`);

  await browser.close();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

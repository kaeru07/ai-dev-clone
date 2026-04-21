# ai-dev-clone

このリポジトリは、各種 AI / 自動化ツールの作業用リポジトリです。現時点では主に `tools/sf6-buckler-export` を含んでおり、ストリートファイター6 公式サイト Buckler's Boot Camp からランクマッチのバトルログを取得して CSV 出力するツールを扱っています。

---

## 現在の主な内容

- `tools/sf6-buckler-export`
  - Buckler's Boot Camp のバトルログ収集
  - Playwright による自動操作
  - CSV エクスポート
  - CSV 統合・重複排除

---

## セットアップ

```bash
git clone https://github.com/kaeru07/ai-dev-clone.git
cd ai-dev-clone
```

主な詳細仕様は以下を参照してください。

- `tools/sf6-buckler-export/READMEforDEV.md`
- `tools/sf6-buckler-export/使い方.md`

---

## 備考

- ルート README はテンプレ状態だったため、現在のリポジトリ内容に合わせて更新しています。
- GitHub 上のリポジトリ名そのものを変更する操作は、この連携からは実行していません。
- もし実体に合わせて repo 名も変えるなら、候補は `sf6-buckler-export` のような名称です。

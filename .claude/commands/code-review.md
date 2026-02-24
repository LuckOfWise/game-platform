# /code-review

未コミットの変更に対する包括的なコードレビューを実行します。

## 実行手順

1. 変更ファイルの取得
```bash
git diff --name-only HEAD
git diff --staged --name-only
```

2. 各ファイルについて以下をチェック

### セキュリティ（CRITICAL）
- ハードコードされた認証情報、APIキー、トークン
- SQLインジェクション脆弱性
- XSS脆弱性
- 入力検証の欠如
- Strong Parametersの未使用

### コード品質（HIGH）
- 50行を超える関数
- 深いネスト（4レベル以上）
- エラーハンドリングの欠如
- N+1クエリ
- Fat Controller/Model

### ベストプラクティス（MEDIUM）
- RESTful設計違反（7アクション以外）
- 不適切な変数名・メソッド名
- DRY原則違反
- テスト不足

3. 自動チェック実行
```bash
bundle exec rubocop --format simple
bundle exec brakeman -q
```

4. レポート生成
- 重大度: CRITICAL, HIGH, MEDIUM, LOW
- ファイル位置と行番号
- 問題の説明
- 修正提案

## 出力形式

```
## レビュー結果

### CRITICAL
- [ファイル:行番号] 問題内容 → 修正案

### HIGH
- [ファイル:行番号] 問題内容 → 修正案

### MEDIUM
- [ファイル:行番号] 問題内容 → 修正案

## 自動チェック結果
[RuboCop, Brakeman の出力]
```

CRITICALまたはHIGH問題がある場合はコミットをブロック推奨。

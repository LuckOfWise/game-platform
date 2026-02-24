# /build-fix

ビルドエラーを解析して修正します。

## 実行手順

1. **エラー情報の収集**
```bash
bundle exec rails assets:precompile 2>&1 || true
yarn build 2>&1 || true
bundle exec rspec --dry-run 2>&1 || true
```

2. **エラーの分類**
   - Ruby構文エラー
   - Rails設定エラー
   - JavaScript/CSSビルドエラー
   - 依存関係エラー
   - テスト設定エラー

3. **エラー分析**
   - エラーメッセージの解析
   - スタックトレースの確認
   - 関連ファイルの特定

4. **修正の実施**
   - 根本原因の特定
   - 最小限の修正を適用
   - 修正後の検証

5. **検証**
```bash
bundle exec rubocop [修正ファイル]
bundle exec rspec [関連テスト]
```

## エラータイプ別対応

### Ruby構文エラー
```bash
ruby -c [ファイル名]  # 構文チェック
```

### 依存関係エラー
```bash
bundle install
bundle update [gem名]
```

### JavaScript/CSSビルドエラー
```bash
yarn install
yarn build
```

### マイグレーションエラー
```bash
bin/rails db:migrate:status
bin/rails db:migrate
```

## 出力形式

```markdown
## ビルドエラー分析

### エラー内容
[エラーメッセージ]

### 原因
[根本原因の説明]

### 修正内容
- ファイル: [ファイル名]
- 変更: [変更内容]

### 検証結果
[修正後のビルド結果]
```

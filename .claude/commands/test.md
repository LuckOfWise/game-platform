# /test

テストの実行と結果分析を行います。

## 実行手順

1. **全テスト実行**
```bash
bundle exec rspec
```

2. **失敗テストの分析**
   - エラーメッセージの解析
   - 失敗箇所の特定
   - 期待値と実際の値の比較

3. **修正方針の決定**
   - テストの問題か実装の問題かを判断
   - 実装を修正（テストが正しい場合）
   - テストを修正（実装が正しい場合）

4. **再実行と検証**
```bash
bundle exec rspec [失敗したテストファイル]
```

## オプション

### 特定ファイルのテスト
```bash
bundle exec rspec spec/models/user_spec.rb
```

### 特定行のテスト
```bash
bundle exec rspec spec/models/user_spec.rb:42
```

### カバレッジ確認
```bash
COVERAGE=true bundle exec rspec
```

## テスト作成ガイドライン

`doc/agent/spec.md` を参照して以下を遵守：

- describe, context, it は日本語で記述
- AAA パターン（Arrange, Act, Assert）
- 具体的な期待値をベタ書き（変数使用禁止）
- factory_bot の trait を活用

## 出力形式

```markdown
## テスト結果

### 実行結果
- 総テスト数: xxx
- 成功: xxx
- 失敗: xxx
- 保留: xxx

### 失敗テスト
1. [テストファイル:行番号]
   - 期待: xxx
   - 実際: xxx
   - 原因: xxx
   - 修正案: xxx

### 推奨アクション
- [ ] xxx の修正
```

# コーディングスタイル

## 基本原則

### コメント規約
- **基本的にコメントは記述しない**
- コードは自己説明的であることを優先
- 変数名、メソッド名、クラス名は英語

### 例外: TODOコメント
対応期限が明確な場合のみ：
```ruby
# TODO[YYYY-MM-DD]: 対応内容の説明
```

## ファイル構成

- 小さなファイルを多数 > 大きなファイルを少数
- 高凝集・低結合
- 機能/ドメイン別に整理

## Rubyスタイル

### メソッドの長さ
- 目安: 20行以下
- 長い場合はプライベートメソッドに分割

### ネストの深さ
- 最大4レベル
- 深い場合は早期リターンやガード節を使用

```ruby
# 禁止: 深いネスト
def process
  if condition1
    if condition2
      if condition3
        # 処理
      end
    end
  end
end

# 推奨: 早期リターン
def process
  return unless condition1
  return unless condition2
  return unless condition3
  # 処理
end
```

## エラーハンドリング

```ruby
# 適切なエラーハンドリング
def fetch_data
  response = api_client.get(url)
  response.body
rescue ApiError => e
  Rails.logger.error("API error: #{e.message}")
  raise
end
```

## コード品質チェックリスト

作業完了前に確認：

- [ ] コードが読みやすく、適切に命名されている
- [ ] 関数が短い（20行以下目安）
- [ ] 深いネストがない（4レベル以下）
- [ ] 適切なエラーハンドリング
- [ ] ハードコードされた値がない
- [ ] DRY原則に従っている

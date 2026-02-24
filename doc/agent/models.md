# モデルレイヤー開発ガイドライン

## 基本原則

### バリデーションの責務

- **パラメータ検証の責任**:
  コントローラーから受け取ったパラメータの妥当性検証はモデルの責務
- **ビジネスルールの実装**:
  データの整合性やビジネスルールに関する検証はすべてモデルで実装
- **エラーメッセージ**: 具体的で分かりやすいエラーメッセージを設定する

### バリデーション実装例

```ruby
class Resource < ApplicationRecord
  validates :name, presence: true
  validates :description, length: { maximum: 500 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :custom_validation_method

  private

  def custom_validation_method
    if some_complex_condition?
      errors.add(:base, 'エラーの詳細な説明')
    end
  end
end
```

## 並び順管理

### 基本的なアプローチ

レコードの並び順が必要な場合は、以下のアプローチを検討します：

#### 1. タイムスタンプによる並び順（推奨）

```ruby
class Post < ApplicationRecord
  scope :recent, -> { order(created_at: :desc) }
  scope :oldest_first, -> { order(created_at: :asc) }
end
```

#### 2. 明示的なpositionカラムを使用

特定の順序を管理者が手動で制御する必要がある場合：

```ruby
class Story < ApplicationRecord
  belongs_to :book

  scope :ordered, -> { order(:position) }

  def move_to(new_position)
    update(position: new_position)
  end
end
```

#### 実装時の注意事項

- **カラム型**: `position` カラムは integer型、NOT NULL制約を推奨
- **インデックス**: 親子関係がある場合は複合インデックス（例: `[book_id, position]`）を作成
- **デフォルト値**: マイグレーション時に適切なデフォルト値を設定
- **並び替えロジック**: 複雑な並び替えが必要な場合は、専用のサービスクラスを作成

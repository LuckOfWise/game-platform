# マイグレーション開発ガイドライン

## 基本ルール

### changeメソッドの使用
- **up, downメソッドの使用は禁止**
- **必ずchangeメソッドを使用すること**
- changeメソッドを使用することで、Railsが自動的にrollback処理を生成する

### 文字列カラムのnull制約
- **`string`や`text`といった文字列カラムでは基本的にnullを許容しない**
- 未入力を許容する場合は`default: ''`として定義する
- データの一貫性を保つため、可能な限りnull値を避ける

### インデックス作成時の注意点
- **カーディナリティが低い（取りうる値が少ない）カラムには単独でのインデックス作成を避ける**
- **理由**: 例えば`role`カラムに"admin"と"operator"の2つの値しかない場合、そのカラムだけのインデックスは検索性能向上にほとんど寄与しない
- カーディナリティが低いカラムでインデックスが必要な場合は、他のカラムとの複合インデックスを検討する
- 一般的に、カーディナリティが全レコード数の10%未満の場合は単独インデックスの効果は薄い

### 既存データの更新
- **既存データの更新は必ずexecuteメソッドによるSQL実行で行うこと**
- モデルのメソッドやActiveRecordのメソッドは使用しない
- **理由**: モデルのメソッド等を利用すると将来メソッドが存在しなくなった場合にエラーとなる

**例（推奨）**：
```ruby
def change
  add_column :users, :status, :string, default: 'active', null: false, comment: 'ユーザーの状態（active/inactive）'
  add_column :users, :bio, :text, default: '', null: false, comment: 'ユーザーの自己紹介文'
  add_column :users, :email, :string, null: false, comment: 'ユーザーのメールアドレス'

  # 既存データの更新はSQL実行で行う
  reversible do |dir|
    dir.up do
      execute "UPDATE users SET status = 'active' WHERE status IS NULL"
    end
  end

  # カーディナリティが高いカラムにはインデックスを作成
  add_index :users, :email, unique: true, name: 'index_users_on_email'

  # カーディナリティが低いカラムと組み合わせた複合インデックス
  add_index :users, [:status, :created_at], name: 'index_users_on_status_and_created_at'
end
```

**例（禁止）**：
```ruby
def change
  # DBコメントが未定義（基本的に禁止）
  add_column :users, :status, :string, default: 'active'

  # nullを許容している（基本的に禁止）
  add_column :users, :bio, :text, null: true

  # カーディナリティが低いカラムへの単独インデックス（効果が薄い）
  add_index :users, :role  # roleが"admin"と"operator"の2値しかない場合は不要

  # モデルメソッドの使用は禁止
  User.where(status: nil).update_all(status: 'active')
end
```

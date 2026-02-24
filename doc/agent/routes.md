# ルーティング開発ガイド

## 設計原則（DHHのアプローチを採用）

### RESTfulコントローラーの徹底

- **7つの標準アクション（index, show, new, edit, create, update, destroy）のみを使用**
- カスタムアクションが必要な場合は、新しいコントローラーを作成
- 1コントローラー = 1リソースの責務を守る

### 専用コントローラーの活用

```ruby
# 推奨: 状態やスコープごとに専用コントローラー
namespace :inboxes do
  resources :pendings, only: [:index]
  resources :archived_items, only: [:index]
end

# 非推奨: クエリパラメータでの分岐
resources :inboxes do
  collection do
    get :pending  # カスタムアクション（避ける）
  end
end
```

## 必須ルール

### ネストは可能な限り3レベルまでに抑える

- **努力目標として、ネストは3レベルまでを推奨**
- 4レベル以上のネストは複雑性を増すため、要件上必要な場合のみ使用
- 深いネストが必要な場合は設計の見直しも検討する

## 設計パターン

### 単一目的コントローラー

```ruby
# 推奨: 特定の操作に特化したコントローラー
resources :purchases, only: [:create]
resources :costs_calculations, only: [:create]

namespace :company do
  resource :account_details, only: [:update]
  resource :website_details, only: [:update]
end
```

### スコープベースの分離

```ruby
# 推奨: 明確なスコープごとのコントローラー
namespace :admin do
  resources :users
end

namespace :api do
  namespace :v1 do
    resources :users, only: [:index, :show]
  end
end
```

## 新規追加時のチェック

1. **ネストは3レベルまでか**（努力目標）
2. **module指定があるか**
3. **アクション制限（only/except）があるか**
4. **RESTfulな7つのアクションのみか**
5. **単一責務の原則に従っているか**

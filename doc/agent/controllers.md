# コントローラーレイヤー開発ガイドライン

## 基本原則

### RESTfulなリソース設計
- リソースベースのURL設計を基本とする
- 標準的な7つのアクション（index, show, new, create, edit, update, destroy）を活用
- カスタムアクションは必要最小限に留める

### シンプルなコントローラー
- ビジネスロジックはモデルに委譲
- 1アクションあたりの責務を単一に保つ
- before_actionの使用は適切な範囲に留める

## 認証

### 認証の実装
- 認証が必要なコントローラーでは明示的に記述

```ruby
class SomeController < ApplicationController
  before_action :authenticate_user!
end

class Admins::ApplicationController < ApplicationController
  before_action :require_admin!
end
```

## エラーハンドリング

### 基本方針
- Railsの標準的な例外処理機構を活用し、過度な防御的プログラミングは避ける
- エッジケースのエラーは適切な例外が発生するため、Railsの例外処理に任せる
- ビジネスロジック上必要な場合のみカスタムエラー処理を実装

### 実装ガイドライン

#### 標準的な例外はRailsに任せる
`ActiveRecord::RecordNotFound`、`ActionController::ParameterMissing`などの標準的な例外は、Railsが適切にハンドリングするため追加の処理は不要。

```ruby
def set_project
  @project = Project.find(params[:project_id])
end
```

#### ビジネスロジック固有のエラー処理
業務要件として特別な処理が必要な場合のみ、明示的なエラーハンドリングを実装。

```ruby
def create_payment
  PaymentService.new(@project).process!
rescue PaymentService::InsufficientFundsError => e
  redirect_to project_path(@project), alert: '残高が不足しています'
end
```

### エラーページのカスタマイズ
`public/`ディレクトリのエラーページをカスタマイズし、ユーザーフレンドリーなメッセージを表示。

## N+1問題対策

### 基本方針
- **preloadを優先的に使用** - includesよりもpreloadを使用してクエリの挙動を明確にする
- strict_loadingと組み合わせて、実際にN+1が発生している箇所のみ対策する
- 必要なアソシエーションのみを読み込み、過度なeager loadingは避ける

### 実装例

```ruby
def index
  @projects = Project.strict_loading.preload(:user, :rewards).page(params[:page])
end

def featured
  @projects = Project.joins(:category)
                    .where(categories: { featured: true })
                    .preload(:user)
                    .includes(:category)
end
```

## 検索機能の実装方針

### 検索機能の実装
- **Ransackを避ける**
- scopeの組み合わせもしくはFormObjectで実装する
- コードを読んだ時に自明で、組み立てられるクエリも制御しやすい実装を選択

## Turbo使用ガイドライン

### 基本方針
- **turbo_streamの使用は原則禁止** - 特別な指示があった場合のみ使用
- 画面の部分更新が必要な場合は、より単純な仕組みを優先的に採用
- turbo_driveはデフォルトで無効（`data-turbo="true"`で明示的に有効化が必要）

### 実装優先順位
画面の部分更新が必要な場合、以下の優先順位で実装方法を検討する：

1. **turbo_frame（推奨）**
   - 特定の領域のみを更新する場合に最適
   - HTMLのマークアップのみで動作し、追加のJavaScriptが不要
   - 実装がシンプルで保守性が高い

2. **turbo_drive（明示的な有効化が必要）**
   - ページ全体の遷移を高速化したい場合に使用
   - `data-turbo="true"`属性を追加して有効化
   - フォーム送信やリンクごとに個別に制御可能

3. **turbo_stream（特別な場合のみ）**
   - 複数の異なる領域を同時に更新する必要がある場合
   - WebSocketを使用したリアルタイム更新が必要な場合
   - **使用前に必ずチームと協議すること**

### 実装例

#### turbo_frameを使用した部分更新（推奨）
```erb
<%= turbo_frame_tag "search_results" do %>
  <div class="grid gap-4">
    <%= render @projects %>
  </div>
<% end %>

<%= form_with url: search_projects_path, data: { turbo_frame: "search_results" } do |f| %>
  <%= f.text_field :query %>
  <%= f.submit "検索" %>
<% end %>
```

```ruby
def search
  @projects = Project.search(params[:query])
end
```

#### turbo_driveを明示的に有効化する場合
```erb
<%= link_to "次のページ", next_page_path, data: { turbo: "true" } %>

<%= form_with model: @project, data: { turbo: "true" } do |f| %>
  <%= f.text_field :name %>
  <%= f.submit %>
<% end %>
```

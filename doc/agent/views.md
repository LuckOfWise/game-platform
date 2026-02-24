# View レイヤー開発ガイドライン

このファイルは `app/views` 配下のファイルで作業する際のガイダンスを提供します。

## 保守性重視の開発制約

### 基本原則
- 長期的なメンテナンス性を優先する
- 新機能開発時は必ず既存の実装パターンを確認・踏襲する
- 技術的負債の蓄積を避け、持続可能な開発を維持する

## スタイリング原則
- 詳細は `styles.md` を参照

### CSS クラス命名規則（BEM）

#### 1 View = 1 Block の原則

**各ビューファイルは1つのトップレベルBlockを持ち、その中の要素はすべてそのBlockのElementとして定義します。**

```erb
<%# 推奨: 1つのトップレベルBlock %>
<div class="game-page">
  <header class="game-page__header">...</header>
  <div class="game-page__content">...</div>
  <footer class="game-page__footer">...</footer>
</div>

<%# 禁止: 複数の独立したBlock %>
<div class="game-page">
  <header class="game-header">...</header>  <%# game-page__headerであるべき %>
  <div class="game-content">...</div>
</div>
```

#### 例外: 再利用可能なコンポーネント
`components/` の汎用コンポーネント（btn, badge, alert等）は独立したBlockとして使用可。

#### 基本構文
- **Block**: `.block-name`（ビューに対応するトップレベル要素）
- **Element**: `.block-name__element-name`（Block内の要素）

### State クラス（`.is-*`）の使い方

**重要**: `.is-*`は**動的な状態変化**のみに使用し、スタイルのバリエーションには使用しない。

#### 適切な使用（状態変化）
```erb
<span class="game-mgmt__status-badge is-<%= @game.status %>">...</span>
<button class="url-copy__btn" data-copied-class="is-copied">コピー</button>
```

#### 不適切な使用（バリエーション）
```erb
<%# サイズやレイアウトは状態ではない %>
<div class="card-body is-center">...</div>
<div class="card-body is-lg">...</div>
```

#### 正しいバリエーションの表現
```erb
<%# バリエーションは別のElement名で定義 %>
<div class="team-entry__card-body">...</div>
<div class="team-entry__result-body">...</div>
```

#### 例外: 再利用可能なコンポーネント
`components/` の汎用コンポーネントではバリエーションにState classを使用可：
```erb
<%= link_to "保存", path, class: "btn is-primary is-lg" %>
<span class="badge is-owner">オーナー</span>
<div class="alert is-danger">エラー</div>
```

### レイアウト設計原則
- **marginの直接使用を最小限に抑える** - パーシャル内にmarginを記述しない
- **外部からの余白制御** - 親要素でmarginを調整し、パーシャルの再利用性を向上

## Viewテンプレート使用時の制約

### 1. レイアウト制御の分離とmargin設計
```erb
<%# パーシャル内にmargin記述は禁止 %>
<div class="component" style="margin-bottom: 16px;">
  <%# パーシャルの内容 %>
</div>

<%# 外部からの余白制御を推奨 %>
<div class="component-wrapper">
  <%= render 'shared/component' %>
</div>

<%# BEMクラスを活用したレイアウト %>
<div class="component-list">
  <%= render 'shared/component1' %>
  <%= render 'shared/component2' %>
</div>
```

### 2. 条件分岐による重複コードの禁止
条件によって属性だけが異なるような重複コードを避ける。

```erb
<%# 禁止 %>
<% if preview_mode? %>
  <%= button_to 'フォロー', follow_path, class: 'btn is-primary', disabled: true %>
<% else %>
  <%= button_to 'フォロー', follow_path, class: 'btn is-primary' %>
<% end %>

<%# 推奨 %>
<%= button_to 'フォロー', follow_path, class: 'btn is-primary', disabled: preview_mode? %>
```

## テンプレートガイドライン
- 全てのテンプレートで **ERB** を使用

## エラー表示

### フォームのエラー表示
```erb
<% if @object.errors.any? %>
  <%= render 'shared/error_messages', object: @object %>
<% end %>
```

## コード品質制約
- DOM構造の深度を最小限に抑える
- 複雑なロジックはヘルパーメソッドに移動
- ビューに条件分岐が多い場合は、デコレーターパターンの導入を検討

## チェックリスト
- [ ] 1 View = 1 Block の原則に従っている
- [ ] State class（`.is-*`）は状態変化のみに使用している
- [ ] バリエーションは別のElement名で定義している
- [ ] marginの直接記述を避け、外部からの余白制御を採用
- [ ] 条件分岐による重複コードを回避
- [ ] パーシャルは単一の責務を持つように設計

## 例外規則
パフォーマンス上の重大な問題、外部ライブラリとの統合、レガシーコードとの互換性が必要な場合のみ例外を認める。

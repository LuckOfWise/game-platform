# CSS Style ガイドライン

## 重要なこと

* 予想ができるようにする
    * どこに書くのかすぐに分かるように
    * ターゲットはRailsプログラマ
* JSの動きにCSSの記載が影響しないようにする
    * CSSのリファクタリング時にJSが影響しないように
* 記述量の多さより、継承などによる相互影響を少なくする
* すぐに読んで理解できる名前付けを行う

## 使用技術

* 本プロジェクトは**CSS**を使用します（Propshaft経由で配信）
* 必要に応じてCSS Custom Propertiesを活用します

## レスポンシブデザイン

### 基本原則

* **モバイルファーストで設計**し、スマホでの表示を常に意識する
* 不要な横スクロールや改行が発生しないように実装する

### 横スクロールを防ぐ

```css
/* 良い例: 幅がビューポートを超えない */
.block__element {
  max-width: 100%;
  overflow-wrap: break-word;
  word-break: break-word;
}

/* 良い例: flexで折り返し */
.block__list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

/* 悪い例: 固定幅でビューポートを超える */
.block__element {
  width: 500px;
}
```

### 不要な改行を防ぐ

```css
/* 良い例: 適切な折り返し制御 */
.block__text {
  white-space: normal;
}

/* 良い例: 1行に収めたい要素 */
.block__label {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
```

### 実装チェックリスト

* [ ] 固定幅（px）を使う場合は `max-width: 100%` も併用する
* [ ] 長いテキストには `overflow-wrap: break-word` を設定する
* [ ] flexレイアウトでは `flex-wrap: wrap` を検討する
* [ ] スマホ実機またはDevToolsで320px〜375pxの幅で表示確認する
* [ ] 横スクロールバーが表示されないことを確認する

## 命名規則

* Block、Elementに関する命名はBEMを採用し、Modifierが必要な場合は別途State用のクラスを作成します。

```css
/* 良い例（フラット＆Stateのみネスト） */
.block { }
.block__element { }
.block__element.is-hidden { }
.block__element.is-shown { }
```

### 主な方針

* クラス名は`Block__Element`の規則で名づけます。
* **1 View = 1 Block**: 各ビューファイルは1つのトップレベルBlockを持ち、その中の要素はすべてそのBlockのElementとして定義します。
* ElementはBlock内の要素（input, li等）に対して設定します。
* 要素セレクタ（aタグなど）にスタイルを設定しないようにします。
* Media Queryは Element毎に設定します。
* IDセレクタは「スタイルのためだけ」に使用しません（JSのターゲットやアンカー用途は可）。

### State クラス（`.is-*`）の使い方

* BEMの`--modifier`は使用せず、**動的な状態変化**にのみStateクラス（`.is-*`）を使用します。
* **重要**: `.is-*`は「状態の変化」を表すためのものであり、スタイルのバリエーションには使用しません。

#### 適切な使用例（状態変化）

```css
.game-mgmt__status-badge.is-preparing { /* 準備中状態 */ }
.game-mgmt__status-badge.is-active { /* アクティブ状態 */ }
.game-mgmt__status-badge.is-closed { /* 終了状態 */ }

.url-copy__btn.is-copied { /* コピー完了状態 */ }
.btn.is-disabled { /* 無効状態 */ }
```

#### 不適切な使用例（バリエーション）

```css
/* 悪い例：サイズやレイアウトのバリエーションにis-*を使う */
.card-body.is-center { /* レイアウトは状態ではない */ }
.card-body.is-lg { /* サイズは状態ではない */ }
```

#### 正しいバリエーションの表現方法

バリエーションが必要な場合は、別のElement名として定義します：

```css
/* 良い例：別のElement名を使う */
.team-entry__card-body { padding: 40px; }
.team-entry__result-body { padding: 60px 40px; text-align: center; }

.team-entry__icon { /* 通常アイコン */ }
.team-entry__icon-closed { /* 終了アイコン */ }
```

#### 例外: 再利用可能なコンポーネント

`components/` の汎用コンポーネント（btn, badge, alert等）では、バリエーションにState classを使用できます：

```css
/* コンポーネントは例外的にバリエーションにis-*を使用可 */
.btn.is-primary { }
.btn.is-secondary { }
.btn.is-sm { }
.btn.is-lg { }
```

* 子孫セレクタ（`.block .child`）や複雑なネストは避けます。必要な場合はElementクラスを追加して回避します。

### 命名の区切り方

* `-`（ハイフン）区切りのスネークケースで命名します。

### CSSファイル名・構成

* CSSのファイル名はBlock名はハイフン区切りで合わせます。
  * 例: `game-page.css`, `dashboard.css`
* **1つのCSSファイルには1つのトップレベルBlockのみ**を定義します（1ファイル=1 Block）。
* JSのプレフィックス`js-`はJSのためだけに使い、スタイルを当てません。スタイルが必要な場合は別途スタイル用クラスを定義して併記します。

### 1 View = 1 Block の原則（詳細）

各ビューファイルは1つのトップレベルBlockを持ち、ビュー内のすべての要素はそのBlockのElementとして定義します。

```css
/* 良い例: 1つのトップレベルBlock */
.game-page {
  display: flex;
  flex-direction: column;
}
.game-page__header {
  padding: 40px;
}
.game-page__header-title {
  font-size: 24px;
}
.game-page__content {
  flex: 1;
  padding: 20px;
}
.game-page__footer {
  padding: 16px 20px;
}
```

```css
/* 悪い例: 複数の独立したBlock */
.game-page {
  display: flex;
}
.game-header {  /* これはgame-page__headerであるべき */
  padding: 40px;
}
.game-content { /* これはgame-page__contentであるべき */
  flex: 1;
}
```

#### 例外: 再利用可能なコンポーネント

複数のビューで使用される汎用的なコンポーネント（ボタン、バッジ、アラート、カード等）は、独立したBlockとして `components/` ディレクトリに定義します。

```erb
<%# ビュー固有の要素はBlockのElementとして %>
<div class="game-page">
  <header class="game-page__header">...</header>

  <%# 再利用可能なコンポーネントは独立したBlock %>
  <div class="alert is-danger">...</div>
  <button class="btn is-primary">...</button>
</div>
```

### 要素の名前の付け方

* Railsで出てくる項目名（inputなど）が当てはまるなら、そのままつけます。
* ブロック内をラップするようなクラスが欲しい場合は`Block__container`と命名します。

### JSでクラスにイベントを紐付ける

* JSでイベントを紐付ける場合にクラス名を指定する場合は、`js-`というプリフィクスを設定します。
* `js-`プリフィクスのついたクラスにスタイルをあててはいけません。必要な場合はスタイル用のクラスを別途付与します。

## ファイル構造

### ディレクトリ構成

```
app/assets/stylesheets/
├── application.css
├── initializers/    - 変数（CSS Custom Properties）、デザイントークン
├── base/           - リセット、基本スタイル
├── layout/         - レイアウト（header, footer等）
├── components/     - 再利用可能コンポーネント
└── views/          - ビュー固有スタイル（1 view = 1 block）
```

### 各ディレクトリの役割

#### initializers/
* 配色、フォント、スペーシング等のデザイントークンを定義
* CSS Custom Propertiesを定義

#### base/
* CSSリセット、基本的なHTML要素のスタイル

#### layout/
* ページ共通のレイアウト（header, footer, main等）

#### components/
* **再利用可能**なコンポーネント（複数のビューで使用）
* 例: `btn`, `badge`, `alert`, `card`
* State classによるバリエーション可（`.is-primary`, `.is-lg`等）

#### views/
* **ビュー固有**のスタイル（1 view = 1 block）
* ファイル名はBlock名に対応（例: `game-page.css` → `.game-page`）
* State classは状態変化のみ使用

### ファイル命名規則

* CSSファイル名はBlock名はハイフン区切り
* 例: `game-page.css`, `dashboard.css`, `team-entry.css`
* 1ファイル = 1 Block（トップレベルBlockを1つだけ定義）

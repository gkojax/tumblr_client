# CLAUDE.md

このファイルは Claude Code（claude.ai/code）がこのリポジトリで作業する際のガイダンスを提供します。

## クイックコマンド

```bash
# 初期セットアップ
bundle install

# 全テスト実行
rake test

# 単一テストファイル実行
bundle exec rspec spec/examples/client_spec.rb

# 単一テスト実行
bundle exec rspec spec/examples/client_spec.rb:42

# gem をビルド
rake build

# リリース（タグ作成、リモート push、rubygems.org に公開）
rake release

# ローカルにインストール
gem install pkg/tumblr_client-*.gem
```

## アーキテクチャ概要

**Ruby バージョン**: 2.7、3.0 以上を推奨（CI テスト対象：2.6、2.7、3.0）

**tumblr_client** は Tumblr v2 API への OAuth 認証 HTTP ラッパーです。OAuth フロー自体は実装しておらず、ユーザーが Ruby OAuth gem を使用して 3-legged OAuth ハンドシェイクを完了し、このクライアントを設定する必要があります。

### コア設計

`Tumblr::Client` クラスは複数のモジュールを include する合成インターフェースであり、各モジュールが関連する API メソッドをグループ化しています：

- **`Blog`** — ブログ情報、投稿、キュー、下書き、フォロワー、設定
- **`User`** — ユーザー情報、制限、プリファレンス
- **`Post`** — 投稿作成（テキスト、画像、動画、音声、引用、リンク、チャット）
- **`Tagged`** — タグで投稿を検索
- **`Request`** — リクエスト構築と HTTP 実行
- **`Connection`** — Faraday セットアップと認証情報管理

### リクエストフロー

1. ユーザーが `Client` のメソッドを呼び出す（例：`client.info`）
2. メソッドはミックスインモジュールの1つで定義される（例：`User#info`）
3. メソッドはリクエストパラメータを構築し、内部の `#request` メソッドを呼び出す（`Request` ミックスインから）
4. `#request` は接続（Faraday）を使用して OAuth 署名付き HTTP 呼び出しを実行
5. Faraday 2.x ミドルウェア（oauth_signature、url_encoded、json）が OAuth 署名とシリアライゼーションを処理
6. レスポンスは JSON として解析され、Hash として返される

### 設定フロー

グローバル設定は `Tumblr.configure` ブロック経由で設定されます：

```ruby
Tumblr.configure do |config|
  config.consumer_key = "..."
  config.consumer_secret = "..."
  config.oauth_token = "..."
  config.oauth_token_secret = "..."
end
```

クライアント毎の設定オーバーライドは `Tumblr::Client.new` に渡されます：

```ruby
client = Tumblr::Client.new(consumer_key: "...", oauth_token: "...")
```

## テスト慣例

- **RSpec** はテストフレームワーク
- **WebMock** は HTTP レスポンスをモック；テストで実 API を呼び出さない
- **SimpleCov** はカバレッジを追跡
- テストファイルはモジュール名をミラー：`spec/examples/{blog,user,post,tagged,client,request}_spec.rb`

API エンドポイント追加時：

1. WebMock を使用してリクエスト/レスポンスをモックするテストを最初に書く
2. 適切なモジュール（`Blog`、`User`、`Post`、`Tagged`）にメソッドを実装
3. メソッドは HTTP メソッドとパスを指定して `#request` を呼び出す
4. `spec/examples/` に WebMock スタブを使用した対応するテストを追加
5. SimpleCov でカバレッジが 80% 以上を保つことを確認

### テストパターン例

```ruby
describe Tumblr::Blog do
  let(:client) { Tumblr::Client.new }

  describe '#info' do
    it 'retrieves blog info' do
      stub_request(:get, 'https://api.tumblr.com/v2/blog/example.tumblr.com/info')
        .to_return(status: 200, body: '{"response": {"blog": {...}}}')

      result = client.info('example.tumblr.com')
      expect(result['blog']).not_to be_nil
    end
  end
end
```

## 主要ファイル

| ファイル | 目的 |
|------|---------|
| `lib/tumblr/client.rb` | メインクラス；全ミックスインモジュールを include |
| `lib/tumblr/config.rb` | グローバル設定管理 |
| `lib/tumblr/connection.rb` | Faraday HTTP セットアップと OAuth ミドルウェア |
| `lib/tumblr/request.rb` | リクエスト実行；内部リクエスト構築とレスポンス処理 |
| `lib/tumblr/{blog,user,post,tagged}.rb` | API エンドポイントメソッド（ドメイン別グループ化） |
| `lib/tumblr/helpers.rb` | 共有ユーティリティ関数 |
| `spec/spec_helper.rb` | RSpec 設定と共有セットアップ |
| `spec/examples/*_spec.rb` | WebMock を使用した API メソッドテスト |

## 重要な注記

- **初期セットアップ**: `bundle install` を実行して依存 gem をインストール
- **Git 設定**: `.claude/` を `.gitignore` に追加し、ローカルの Claude Code 設定をコミットから除外
- **OAuth 処理**: このgem は 3-legged OAuth フロー自体は実装しません。ユーザーは Ruby OAuth gem を使用してトークンを取得し、このクライアントを設定する必要があります
- **Faraday アダプタ**: クライアント作成時にカスタム Faraday HTTP アダプタを指定できます：`Tumblr::Client.new(client: :httpclient)`
- **API ホスト**: デフォルトは `api.tumblr.com`。`TUMBLR_API_HOST` 環境変数またはクライアント毎オプションで上書き可能
- **Ruby バージョン**: Ruby 1.9.x～3.x をサポート（CI テスト：2.6、2.7、3.0）

## 新しい API エンドポイント追加

参考：https://www.tumblr.com/docs/en/api/v2（公式）および https://github.com/tumblr/docs（GitHub リポジトリ）

新しい Tumblr API エンドポイントをラップする場合：

1. ドメインを決定：Blog、User、Post、または必要に応じて新規モジュール作成
2. `lib/tumblr/` の適切なモジュールにメソッドを追加
3. `#request(method, path, params)` を使用して HTTP 呼び出しを実行
4. `spec/examples/` に WebMock スタブを使用した対応するテストを追加
5. SimpleCov でカバレッジが 80% 以上を保つことを確認

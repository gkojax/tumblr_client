---
name: test-from-stub
description: WebMock スタブから RSpec テストケース自動生成
user-invocable: true
disable-model-invocation: true
---

# Test From Stub Skill

WebMock スタブの定義からテストケースを自動生成します。

## 使用方法

```
/test-from-stub <api_path> <method>
```

例：
```
/test-from-stub /v2/blog/:blog_name/info get
/test-from-stub /v2/blog/:blog_name/posts post
```

## 処理内容

1. Tumblr API v2 ドキュメントからエンドポイント仕様を取得
2. Request/Response サンプルを取得
3. WebMock スタブ付き RSpec テストケース生成
4. AAA パターン（Arrange-Act-Assert）に従った実装

## テスト例

生成されるテストの形式：

```ruby
describe 'エンドポイント名' do
  let(:client) { Tumblr::Client.new }
  
  describe '#メソッド名' do
    it 'expected behavior' do
      # Arrange: WebMock スタブ設定
      stub_request(:get, 'https://api.tumblr.com/...')
        .to_return(status: 200, body: '{"response": {...}}')
      
      # Act: メソッド呼び出し
      result = client.メソッド名(...)
      
      # Assert: 検証
      expect(result).to match_expected_structure
    end
  end
end
```

## 参考資料

- 実装パターン: CLAUDE.md → 「Example Test Pattern」
- WebMock ドキュメント: https://github.com/bblimke/webmock

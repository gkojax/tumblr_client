---
name: endpoint-generator
description: Tumblr API エンドポイント実装スケルトン生成（API 仕様参照付き）
user-invocable: true
disable-model-invocation: true
---

# Endpoint Generator Skill

Tumblr API v2 のエンドポイント実装をサポートします。

## 使用方法

```
/endpoint-generator <domain> <endpoint_name>
```

例：
```
/endpoint-generator blog info
/endpoint-generator post create
```

## 処理内容

1. Tumblr API v2 ドキュメントを参照してエンドポイント仕様を取得
2. 適切なドメインモジュール（Blog, User, Post, Tagged）に実装スケルトン生成
3. WebMock スタブ付きテストスケルトン生成
4. CLAUDE.md の「Adding New API Endpoints」セクションに従った実装

## 参考資料

- 公式ドキュメント: https://www.tumblr.com/docs/en/api/v2
- GitHub ドキュメント: https://github.com/tumblr/docs
- 実装パターン: CLAUDE.md → 「テスト慣例」セクション

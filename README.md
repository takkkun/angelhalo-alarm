★エンジェル・ヘイローの時間をおしらせ
======================================

インストール
------------

- `$ bundle`

設定
----

- `config/settings.yml.sample`を`config/settings.yml`にリネームする
- `twitter.client`の設定をする（このアクセストークンを持つアカウントからリプライでおしらせされる）
- `alarm`の設定をする
  - `text`はおしらせ用のツイート文章
  - `users`はおしらせ対象のユーザー

### 設定例

```yaml
development:
  twitter:
    client:
      consumer_key: XXX...
      consumer_secret: XXX...
      access_token: XXX...
      access_token_secret: XXX...
  alarm:
    text: '%{recipients} %{group}グループは%{hour}時からエンジェル・ヘイローです'
    users:
      -
        name: takkkun
        group: A
      -
        name: john_doe
        group: A
      -
        name: jane_doe
        group: B
```

この設定で、例えばAグループのエンジェル・ヘイローが10時の場合、"@takkkun @john_doe Aグループは10時からエンジェル・ヘイローです"とリプライが来ます。

起動
----

- `$ foreman start`

デプロイ方法
------------

- Herokuのアカウントを取得する
- Heroku Toolbeltをインストールする
- `$ heroku login`
- `$ git create APP_NAME`
- `config/settings.yml`をコミットする
- `$ heroku config:set VAR=VALUE`で環境変数を設定する
  - 必要な変数は`ALARM_ENV`, `TWITTER_CONSUMER_KEY`, `TWITTER_CONSUMER_SECRET`, `TWITTER_NOTIFIER_ACCESS_TOKEN`, `TWITTER_NOTIFIER_ACCESS_TOKEN_SECRET`の5つ。
- `$ git push heroku master`

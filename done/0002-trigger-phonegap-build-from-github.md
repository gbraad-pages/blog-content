---
Title: Trigger PhoneGap Build from GitHub
Date: 2014-11-4
Category: Misc
Tags: phonegap
---

You can remotely trigger a build by using the [API](https://build.phonegap.com/docs/api)

First you need to get your auth token:
```
$ curl -u me@gbraad.nl-X POST -d "" https://build.phonegap.com/token
```

Test it and retrieve your appid using the following command:
```
$ curl https://build.phonegap.com/api/v1/me?auth_token=[token]
```

After this go to your Github repo, open the admin and go to 'Service hooks'. Add a new WebHook URL (first option) and add yours 
`https://build.phonegap.com/apps/[appid]/build/?auth_token=[token]`

Save this and trigger it with 'Test hook'. When you would open: `https://build.phonegap.com/apps/[appid]/builds` you will probably see a new build.

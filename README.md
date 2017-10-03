This a tool for Cozy team to manage cozy-konnector-libs dependency in konnectors.

⚠️ It needs [yarn](https://yarnpkg.com/) and [jq](https://stedolan.github.io/jq/).

## Usage
Just run
```bash
$> ./updateLibs <konnectors.json>
```

Where `konnectors.json` is a configuration file with the same format as [the one used in
cozy-collect](https://github.com/cozy/cozy-collect/blob/master/src/config/konnectors.json).

## Test
If you just want to test, comment the line where `git push origin` is called and replace it by a `git status` to keep the logs.

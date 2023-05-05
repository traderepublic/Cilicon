# GitHub Runner

## ⚠️ IMPORTANT ⚠️

You will need to edit the [setup-actions.sh](./setup-actions.sh)

```bash
./config.sh --url https://github.com/traderepublic --ephemeral --replace --labels $ALL_LABELS --name $RUNNER_NAME --runnergroup mac-ci --work _work --token $RUNNER_TOKEN
```

- Replace `traderepublic` with your GitHub org
- Replace `mac-ci` with your Github runner group you can see these at https://github.com/organizations/YOURORG/settings/actions/runner-groups</br>❗️If you don't have an [Github Enterprise](https://github.com/enterprise) org you'll need to set the runner group to `default`.
- This doesn't work on personal GitHub accounts, you need an org 😢
